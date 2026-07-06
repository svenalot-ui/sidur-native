import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var lang: Lang {
        didSet { UserDefaults.standard.set(lang.rawValue, forKey: "lang") }
    }
    @Published var theme: String {   // "auto" | "light" | "dark"
        didSet { UserDefaults.standard.set(theme, forKey: "theme") }
    }
    @Published var nusach: String? {
        didSet { UserDefaults.standard.set(nusach, forKey: "nusach") }
    }
    @Published var loc: GeoLoc
    @Published var tab: Int = 0
    @Published var remoteNamed: [String: Date]? = nil    // myzmanim override (online)
    @Published var heading: Double? = nil                // compass (degrees, 0 = north)
    private var lastFetchKey = ""

    // Zmanim live in the location's timezone (matters when device tz ≠ place tz).
    var tz: TimeZone {
        if let id = loc.tzId, let t = TimeZone(identifier: id) { return t }
        return .current
    }
    private let locationManager = LocationManager()

    var usingMyZmanim: Bool { !(remoteNamed?.isEmpty ?? true) }

    func startLocation() {
        locationManager.onUpdate = { [weak self] newLoc in
            Task { @MainActor in
                guard let self else { return }
                var l = newLoc
                if l.name == nil { l.name = self.loc.name }   // keep last known city until geocode resolves
                if l.tzId == nil { l.tzId = self.loc.tzId }
                self.loc = l
                self.refreshZmanim()
            }
        }
        locationManager.start()
        refreshZmanim()   // also fetch for the current (fallback) location immediately
    }

    // MARK: - Rest mode (Shabbat & Yom Tov)
    // The app rests from candle lighting until nightfall of the last rest day —
    // using the phone is not for Shabbat or a chag. Times use the location's timezone.
    private func weekday(_ date: Date = Date()) -> Int {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return cal.component(.weekday, from: date)   // 1=Sun … 6=Fri, 7=Sat
    }

    private func ymd(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private func addDays(_ n: Int, to date: Date = Date()) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return cal.date(byAdding: .day, value: n, to: date) ?? date
    }

    private var candleLighting: Date? {
        currentZmanim.t("CandleLighting") ?? currentZmanim.shkia.map { $0.addingTimeInterval(-18 * 60) }
    }

    // Yom Tov calendar (Hebcal, offline-cached). Israel schedule for an Israeli tz.
    @Published var yomTovDays: [HolidayService.Day] = []
    var inIsrael: Bool { tz.identifier == "Asia/Jerusalem" || tz.identifier == "Asia/Tel_Aviv" }
    private var yomTovSet: Set<String> { Set(yomTovDays.map(\.date)) }
    func yomTov(on date: Date) -> HolidayService.Day? {
        let d = ymd(date)
        return yomTovDays.first { $0.date == d }
    }

    /// Saturday, or a civil day that is Yom Tov.
    private func isRestDay(_ date: Date) -> Bool {
        weekday(date) == 7 || yomTovSet.contains(ymd(date))
    }

    /// True from candle lighting on the eve until nightfall of the last rest day.
    var isResting: Bool {
        let now = Date()
        if isRestDay(now) {
            if isRestDay(addDays(1)) { return true }           // chain continues tonight
            if let e = currentZmanim.tzeit { return now < e }
            return true
        }
        if isRestDay(addDays(1)), let c = candleLighting { return now >= c }
        return false
    }

    /// True from Friday candle lighting until Saturday nightfall (kept for callers
    /// that care specifically about Shabbat, e.g. the rest screen's wording).
    var isShabbat: Bool {
        switch weekday() {
        case 6: if let c = candleLighting { return Date() >= c }; return false
        case 7: if let e = currentZmanim.tzeit { return Date() < e }; return false
        default: return false
        }
    }

    /// The Yom Tov being observed now (today's, or tonight's on the eve), if any.
    var currentYomTov: HolidayService.Day? {
        yomTov(on: Date()) ?? (isResting ? yomTov(on: addDays(1)) : nil)
    }

    /// When the current rest span ends — nightfall of the last consecutive rest day
    /// (handles Shabbat adjoining Yom Tov as one continuous block).
    var restEndsAt: Date? {
        guard isResting else { return nil }
        var last = isRestDay(Date()) ? Date() : addDays(1)     // eve → the span starts tomorrow
        var guardrail = 0
        while isRestDay(addDays(1, to: last)), guardrail < 4 { last = addDays(1, to: last); guardrail += 1 }
        return zmanim(for: last).tzeit
    }

    /// Legacy name used by the Today strip.
    var shabbatEndsAt: Date? { restEndsAt }

    /// Name of the rest span that begins on the evening of `date` (Шаббат / holiday),
    /// or nil when that evening is ordinary or `date` itself already rests
    /// (second-day candles are lit after nightfall — no reminder then).
    func eveningRestName(of date: Date) -> String? {
        let next = addDays(1, to: date)
        guard !isRestDay(date), isRestDay(next) else { return nil }
        if weekday(next) == 7 { return lang == .he ? "שבת" : "Шаббат" }
        if let yt = yomTov(on: next) {
            return lang == .he ? HolidayService.heName(yt.hebrew) : HolidayService.ruName(yt.title)
        }
        return nil
    }

    /// True when `date` falls inside any rest span in the next week — used to keep
    /// zman notifications silent on Shabbat and Yom Tov.
    func isRestTime(_ date: Date) -> Bool {
        if isRestDay(date) {
            if isRestDay(addDays(1, to: date)) { return true }
            if let e = zmanim(for: date).tzeit { return date < e }
            return true
        }
        if isRestDay(addDays(1, to: date)) {
            let z = zmanim(for: date)
            if let c = z.t("CandleLighting") ?? z.shkia.map({ $0.addingTimeInterval(-18 * 60) }) {
                return date >= c
            }
        }
        return false
    }

    // A deliberate, high-friction escape (wrong location/timezone) — bypass this rest span only.
    var shabbatBypassed: Bool {
        Date().timeIntervalSince1970 < UserDefaults.standard.double(forKey: "shabbatBypassUntil")
    }
    func bypassShabbat() {
        let until = restEndsAt?.timeIntervalSince1970 ?? (Date().timeIntervalSince1970 + 26 * 3600)
        UserDefaults.standard.set(until, forKey: "shabbatBypassUntil")
        objectWillChange.send()
    }

    // MARK: compass
    func startCompass() {
        locationManager.onHeading = { [weak self] h in
            Task { @MainActor in self?.heading = h }
        }
        locationManager.startHeading()
    }
    func stopCompass() { locationManager.stopHeading() }

    // Fetch authoritative zmanim from myzmanim for the current location.
    // Key includes the calendar day so times refresh after midnight / on foreground.
    func refreshZmanim() {
        let lat = loc.lat, lng = loc.lng, tz = self.tz
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let d = cal.dateComponents([.year, .month, .day], from: Date())
        let key = "\(Int((lat * 100).rounded()))_\(Int((lng * 100).rounded()))_\(d.year ?? 0)-\(d.month ?? 0)-\(d.day ?? 0)"
        if key == lastFetchKey && remoteNamed != nil { return }
        lastFetchKey = key
        Task { @MainActor in
            if let named = await MyZmanimClient.fetchNamed(lat: lat, lng: lng, date: Date(), tz: tz) {
                self.remoteNamed = named
                // Times changed (new place/day) → pending notifications are stale.
                NotificationScheduler.reschedule(app: self)
            }
        }
        Task { @MainActor in
            let days = await HolidayService.shared.yomTovDays(around: Date(), tz: tz, israel: inIsrael)
            if days != self.yomTovDays {
                self.yomTovDays = days
                NotificationScheduler.reschedule(app: self)   // rest-day filter may change
            }
        }
    }

    // Native engine (offline) merged with myzmanim overrides where available.
    var currentZmanim: Zmanim {
        let native = Zmanim.compute(day: Date(), loc: loc, tz: tz)
        if let r = remoteNamed, !r.isEmpty {
            return Zmanim(named: native.named.merging(r) { _, new in new })
        }
        return native
    }

    init() {
        let d = UserDefaults.standard
        let saved = d.string(forKey: "lang")
        if let saved, let l = Lang(rawValue: saved) {
            lang = l
        } else {
            let code = Locale.current.language.languageCode?.identifier ?? "ru"
            lang = (code == "he" || code == "iw") ? .he : .ru
        }
        theme = d.string(forKey: "theme") ?? "auto"
        nusach = d.string(forKey: "nusach")
        loc = .jerusalem
    }

    var preferredScheme: ColorScheme? {
        switch theme {
        case "light": return .light
        case "dark": return .dark
        default:      // auto → dark from nightfall to sunrise (by actual zmanim)
            let z = currentZmanim
            let now = Date()
            if let night = z.tzeit ?? z.shkia, let rise = z.netz {
                return (now >= night || now < rise) ? .dark : .light
            }
            let h = Calendar.current.component(.hour, from: now)
            return (h >= 20 || h < 6) ? .dark : .light
        }
    }

    var s: Strings { lang.s }

    func zmanim(for day: Date = Date()) -> Zmanim {
        Zmanim.compute(day: day, loc: loc, tz: tz)
    }

    func fmt(_ d: Date?) -> String { ZFmt.time(d, tz) }
}

enum Nusach: String, CaseIterable {
    case ashkenaz, sefard, chabad, edot
    func name(_ lang: Lang) -> String {
        switch self {
        case .ashkenaz: return lang == .he ? "אַשְׁכְּנַז" : "Ашкеназ"
        case .sefard:   return lang == .he ? "סְפָרַד" : "Сфард (хасидский)"
        case .chabad:   return lang == .he ? "חב״ד" : "Хабад (Ари)"
        case .edot:     return lang == .he ? "עֵדוֹת הַמִּזְרָח" : "Эдот а-Мизрах"
        }
    }
}
