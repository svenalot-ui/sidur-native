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

    // GPS is opt-in now — requested only when the user taps "Определить по GPS".
    func startLocation() {
        locationManager.onUpdate = { [weak self] newLoc in
            Task { @MainActor in
                guard let self else { return }
                var l = newLoc
                if l.name == nil { l.name = self.loc.name }   // keep last known city until geocode resolves
                if l.tzId == nil { l.tzId = self.loc.tzId }
                self.loc = l
                self.persistLoc()
                self.remoteNamed = nil; self.lastFetchKey = ""
                self.refreshZmanim()
            }
        }
        locationManager.start()
    }

    /// Pick a city from the curated list (no GPS).
    func selectCity(_ c: City) {
        loc = GeoLoc(lat: c.lat, lng: c.lng, name: c.name(lang), tzId: c.tz)
        persistLoc()
        remoteNamed = nil; lastFetchKey = ""
        refreshZmanim()
    }

    private func persistLoc() {
        let d = UserDefaults.standard
        d.set(loc.lat, forKey: "loc_lat"); d.set(loc.lng, forKey: "loc_lng")
        d.set(loc.name, forKey: "loc_name"); d.set(loc.tzId, forKey: "loc_tz")
    }
    private static func loadLoc() -> GeoLoc? {
        let d = UserDefaults.standard
        guard d.object(forKey: "loc_lat") != nil else { return nil }
        return GeoLoc(lat: d.double(forKey: "loc_lat"), lng: d.double(forKey: "loc_lng"),
                      name: d.string(forKey: "loc_name"), tzId: d.string(forKey: "loc_tz"))
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
        // offline-first: show the last myzmanim result for this day/place immediately.
        if let cached = MyZmanimCache.load("mzc_" + key) { remoteNamed = cached }
        if key == lastFetchKey && remoteNamed != nil { return }
        lastFetchKey = key
        Task { @MainActor in
            if let named = await MyZmanimClient.fetchNamed(lat: lat, lng: lng, date: Date(), tz: tz) {
                self.remoteNamed = named
                MyZmanimCache.save("mzc_" + key, named)
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
        // Only Edot HaMizrach ships with texts for now — migrate any older selection.
        let savedNusach = d.string(forKey: "nusach")
        if let sn = savedNusach, Nusach(rawValue: sn)?.available == false {
            nusach = Nusach.edot.rawValue
        } else {
            nusach = savedNusach
        }
        loc = AppState.loadLoc() ?? .jerusalem
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

// Curated city list for the zmanim location picker (no GPS required).
struct City: Identifiable {
    let ru: String, he: String, lat: Double, lng: Double, tz: String
    var id: String { ru }
    func name(_ lang: Lang) -> String { lang == .he ? he : ru }
    static let all: [City] = [
        City(ru: "Иерусалим",       he: "יְרוּשָׁלַיִם",  lat: 31.7683, lng: 35.2137, tz: "Asia/Jerusalem"),
        City(ru: "Тель-Авив",       he: "תֵּל אָבִיב",    lat: 32.0853, lng: 34.7818, tz: "Asia/Jerusalem"),
        City(ru: "Бней-Брак",       he: "בְּנֵי בְּרַק",   lat: 32.0807, lng: 34.8338, tz: "Asia/Jerusalem"),
        City(ru: "Хайфа",           he: "חֵיפָה",        lat: 32.7940, lng: 34.9896, tz: "Asia/Jerusalem"),
        City(ru: "Ашдод",           he: "אַשְׁדּוֹד",     lat: 31.8040, lng: 34.6550, tz: "Asia/Jerusalem"),
        City(ru: "Беэр-Шева",       he: "בְּאֵר שֶׁבַע",   lat: 31.2518, lng: 34.7913, tz: "Asia/Jerusalem"),
        City(ru: "Нетания",         he: "נְתַנְיָה",      lat: 32.3215, lng: 34.8532, tz: "Asia/Jerusalem"),
        City(ru: "Цфат",            he: "צְפַת",         lat: 32.9646, lng: 35.4960, tz: "Asia/Jerusalem"),
        City(ru: "Тверия",          he: "טְבֶרְיָה",      lat: 32.7959, lng: 35.5300, tz: "Asia/Jerusalem"),
        City(ru: "Эйлат",           he: "אֵילַת",        lat: 29.5577, lng: 34.9519, tz: "Asia/Jerusalem"),
        City(ru: "Москва",          he: "מוֹסְקְבָה",     lat: 55.7558, lng: 37.6173, tz: "Europe/Moscow"),
        City(ru: "Санкт-Петербург", he: "סַנְקְט פֶּטֶרְבּוּרְג", lat: 59.9311, lng: 30.3609, tz: "Europe/Moscow"),
        City(ru: "Киев",            he: "קִייֶב",        lat: 50.4501, lng: 30.5234, tz: "Europe/Kiev"),
        City(ru: "Одесса",          he: "אוֹדֶסָה",      lat: 46.4825, lng: 30.7233, tz: "Europe/Kiev"),
        City(ru: "Нью-Йорк",        he: "נְיוּ יוֹרְק",    lat: 40.7128, lng: -74.0060, tz: "America/New_York"),
        City(ru: "Лондон",          he: "לוֹנְדוֹן",      lat: 51.5074, lng: -0.1278, tz: "Europe/London"),
        City(ru: "Париж",           he: "פָּרִיז",       lat: 48.8566, lng: 2.3522, tz: "Europe/Paris"),
        City(ru: "Берлин",          he: "בֶּרְלִין",      lat: 52.5200, lng: 13.4050, tz: "Europe/Berlin"),
        City(ru: "Торонто",         he: "טוֹרוֹנְטוֹ",    lat: 43.6532, lng: -79.3832, tz: "America/Toronto"),
    ]
}

enum Nusach: String, CaseIterable {
    case edot, ashkenaz, sefard, chabad
    func name(_ lang: Lang) -> String {
        switch self {
        case .ashkenaz: return lang == .he ? "אַשְׁכְּנַז" : "Ашкеназ"
        case .sefard:   return lang == .he ? "סְפָרַד" : "Сфард (хасидский)"
        case .chabad:   return lang == .he ? "חב״ד" : "Хабад (Ари)"
        case .edot:     return lang == .he ? "עֵדוֹת הַמִּזְרָח" : "Эдот а-Мизрах"
        }
    }
    /// Only Edot HaMizrach ships with texts for now; the rest are placeholders.
    var available: Bool { self == .edot }
}
