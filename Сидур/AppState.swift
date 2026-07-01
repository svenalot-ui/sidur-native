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

    let tz = TimeZone.current
    private let locationManager = LocationManager()

    func startLocation() {
        locationManager.onUpdate = { [weak self] newLoc in
            Task { @MainActor in
                guard let self else { return }
                var l = newLoc
                if l.name == nil { l.name = self.loc.name }   // keep last known city until geocode resolves
                self.loc = l
            }
        }
        locationManager.start()
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
        default: return nil   // auto → follow system (zmanim-based auto comes later)
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
