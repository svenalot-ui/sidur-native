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

    // MARK: - Shabbat mode
    // The app rests from Friday candle lighting until Saturday nightfall — using
    // the phone is not for Shabbat. Times are computed in the location's timezone.
    private func weekday(_ date: Date = Date()) -> Int {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return cal.component(.weekday, from: date)   // 1=Sun … 6=Fri, 7=Sat
    }

    private var candleLighting: Date? {
        currentZmanim.t("CandleLighting") ?? currentZmanim.shkia.map { $0.addingTimeInterval(-18 * 60) }
    }

    /// When the current Shabbat ends (Saturday nightfall), or nil if not near Shabbat.
    var shabbatEndsAt: Date? {
        switch weekday() {
        case 7: return currentZmanim.tzeit                                  // Saturday → today's tzeit
        case 6:                                                             // Friday → tomorrow's tzeit
            var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
            if let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) {
                return zmanim(for: tomorrow).tzeit
            }
            return nil
        default: return nil
        }
    }

    /// True from Friday candle lighting until Saturday nightfall.
    var isShabbat: Bool {
        switch weekday() {
        case 6: if let c = candleLighting { return Date() >= c }; return false
        case 7: if let e = currentZmanim.tzeit { return Date() < e }; return false
        default: return false
        }
    }

    // A deliberate, high-friction escape (wrong location/timezone) — bypass this Shabbat only.
    var shabbatBypassed: Bool {
        Date().timeIntervalSince1970 < UserDefaults.standard.double(forKey: "shabbatBypassUntil")
    }
    func bypassShabbat() {
        let until = shabbatEndsAt?.timeIntervalSince1970 ?? (Date().timeIntervalSince1970 + 26 * 3600)
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
