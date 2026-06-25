import Foundation

struct GeoLoc: Equatable {
    var lat: Double
    var lng: Double
    var name: String?
    static let jerusalem = GeoLoc(lat: 31.7683, lng: 35.2137, name: "Jerusalem")
}

struct ZmanVariant: Identifiable {
    let key: String
    let ru: String
    let he: String
    let time: Date?
    var id: String { key }
    func label(_ lang: Lang) -> String { lang == .he ? he : ru }
}

struct ZmanRow: Identifiable {
    let id: String
    let ru: String
    let he: String
    let icon: String
    let main: Date?
    let variants: [ZmanVariant]
    func name(_ lang: Lang) -> String { lang == .he ? he : ru }
}

// Computed zmanim for one day + location.
struct Zmanim {
    let named: [String: Date]

    func t(_ key: String) -> Date? { named[key] }

    // Convenience accessors used by the Today screen.
    var netz: Date? { named["Sunrise"] }
    var chatzot: Date? { named["Chatzos"] }
    var minchaG: Date? { named["MinchaGedola"] }
    var shkia: Date? { named["Sunset"] }
    var tzeit: Date? { named["Tzais8.5"] }

    static func compute(day: Date, loc: GeoLoc, tz: TimeZone) -> Zmanim {
        let solar = SolarTime(lat: loc.lat, lng: loc.lng, tz: tz)
        func ev(_ ang: Double, _ morning: Bool) -> Date? { solar.event(day: day, angleBelowHorizon: ang, morning: morning) }
        func plus(_ d: Date?, _ min: Double) -> Date? { d.map { $0.addingTimeInterval(min * 60) } }

        let netz = ev(0.833, true)
        let shkia = ev(0.833, false)
        let chatzot = solar.solarNoon(day: day)

        // GRA proportional hour (sunrise → sunset)
        var graHour: TimeInterval? = nil
        if let n = netz, let s = shkia { graHour = (s.timeIntervalSince1970 - n.timeIntervalSince1970) / 12 }
        func gra(_ h: Double) -> Date? {
            guard let n = netz, let hr = graHour else { return nil }
            return n.addingTimeInterval(hr * h)
        }
        // MGA proportional hour (alot72 → tzeit72, fixed 72 min)
        let dawn72 = plus(netz, -72), dusk72 = plus(shkia, 72)
        var mgaHour: TimeInterval? = nil
        if let a = dawn72, let z = dusk72 { mgaHour = (z.timeIntervalSince1970 - a.timeIntervalSince1970) / 12 }
        func mga(_ h: Double) -> Date? {
            guard let a = dawn72, let hr = mgaHour else { return nil }
            return a.addingTimeInterval(hr * h)
        }

        var m: [String: Date] = [:]
        func put(_ k: String, _ d: Date?) { if let d = d { m[k] = d } }

        put("Alos72", dawn72)
        put("Alos16.1", ev(16.1, true))
        put("Alos90", plus(netz, -90))
        put("Alos18", ev(18, true))
        put("Misheyakir11.5", ev(11.5, true))
        put("Misheyakir11", ev(11, true))
        put("Misheyakir10.2", ev(10.2, true))
        put("Sunrise", netz)
        put("SofShmaGRA", gra(3))
        put("SofShmaMGA", mga(3))
        put("SofTfilaGRA", gra(4))
        put("SofTfilaMGA", mga(4))
        put("Chatzos", chatzot)
        put("MinchaGedola", gra(6.5))
        put("MinchaGedola30", plus(chatzot, 30))
        put("MinchaKetana", gra(9.5))
        put("Plag", gra(10.75))
        put("Sunset", shkia)
        put("CandleLighting", plus(shkia, -18))
        put("Tzais8.5", ev(8.5, false))
        put("Tzais72", plus(shkia, 72))
        put("Tzais16.1", ev(16.1, false))
        put("Tzais18", ev(18, false))
        put("SolarMidnight", plus(chatzot, 720))

        return Zmanim(named: m)
    }

    // The main list shown on the Zmanim screen (mirrors the PWA's ZMANIM_MAIN).
    func rows() -> [ZmanRow] {
        func v(_ key: String, _ ru: String, _ he: String) -> ZmanVariant {
            ZmanVariant(key: key, ru: ru, he: he, time: named[key])
        }
        return [
            ZmanRow(id: "alot", ru: "Алот а-Шахар", he: "עֲלוֹת הַשַּׁחַר", icon: "sunrise", main: t("Alos72"),
                    variants: [v("Alos72","72 минуты","72 דקות"), v("Alos16.1","16.1°","16.1°"),
                               v("Alos90","90 минут","90 דקות"), v("Alos18","18°","18°")]),
            ZmanRow(id: "misheyakir", ru: "Мишеякир", he: "מִשֶּׁיַּכִּיר", icon: "sunrise", main: t("Misheyakir11.5"),
                    variants: [v("Misheyakir11.5","11.5°","11.5°"), v("Misheyakir11","11°","11°"),
                               v("Misheyakir10.2","10.2°","10.2°")]),
            ZmanRow(id: "netz", ru: "Нец · восход", he: "הָנֵץ הַחַמָּה", icon: "sun.max", main: t("Sunrise"),
                    variants: [v("Sunrise","Восход","הנץ")]),
            ZmanRow(id: "shmaMGA", ru: "Соф зман Шма · МА", he: "סוֹף זְמַן ק״ש · מג״א", icon: "book", main: t("SofShmaMGA"),
                    variants: [v("SofShmaMGA","Маген Авраам","מג״א")]),
            ZmanRow(id: "shmaGRA", ru: "Соф зман Шма · Гра", he: "סוֹף זְמַן ק״ש · גר״א", icon: "book", main: t("SofShmaGRA"),
                    variants: [v("SofShmaGRA","Гра","גר״א")]),
            ZmanRow(id: "tfilaMGA", ru: "Соф зман Тфила · МА", he: "סוֹף זְמַן תְּפִלָּה · מג״א", icon: "book", main: t("SofTfilaMGA"),
                    variants: [v("SofTfilaMGA","Маген Авраам","מג״א")]),
            ZmanRow(id: "tfilaGRA", ru: "Соф зман Тфила · Гра", he: "סוֹף זְמַן תְּפִלָּה · גר״א", icon: "book", main: t("SofTfilaGRA"),
                    variants: [v("SofTfilaGRA","Гра","גר״א")]),
            ZmanRow(id: "chatzot", ru: "Хацот · полдень", he: "חֲצוֹת הַיּוֹם", icon: "sun.max", main: t("Chatzos"),
                    variants: [v("Chatzos","Солнечный полдень","חצות")]),
            ZmanRow(id: "minchaG", ru: "Минха гдола", he: "מִנְחָה גְּדוֹלָה", icon: "clock", main: t("MinchaGedola"),
                    variants: [v("MinchaGedola","Стандарт","רגיל"), v("MinchaGedola30","+30 минут","30 דקות")]),
            ZmanRow(id: "minchaK", ru: "Минха ктана", he: "מִנְחָה קְטַנָּה", icon: "clock", main: t("MinchaKetana"),
                    variants: [v("MinchaKetana","Стандарт","רגיל")]),
            ZmanRow(id: "plag", ru: "Плаг hа-Минха", he: "פְּלַג הַמִּנְחָה", icon: "clock", main: t("Plag"),
                    variants: [v("Plag","Стандарт","רגיל")]),
            ZmanRow(id: "shkia", ru: "Шкия · закат", he: "שְׁקִיעָה", icon: "sunset", main: t("Sunset"),
                    variants: [v("Sunset","Закат","שקיעה"), v("CandleLighting","Зажигание свечей","הדלקת נרות")]),
            ZmanRow(id: "tzeit", ru: "Цет а-кохавим", he: "צֵאת הַכּוֹכָבִים", icon: "moon.stars", main: t("Tzais8.5"),
                    variants: [v("Tzais8.5","8.5° (Геоним)","8.5°"), v("Tzais72","72 мин · Рабейну Там","72 ר״ת"),
                               v("Tzais16.1","16.1°","16.1°"), v("Tzais18","18°","18°")]),
            ZmanRow(id: "midnight", ru: "Хацот ночи", he: "חֲצוֹת הַלַּיְלָה", icon: "moon", main: t("SolarMidnight"),
                    variants: [v("SolarMidnight","Полночь","חצות")]),
        ]
    }
}

// Time formatting helpers.
enum ZFmt {
    static func time(_ d: Date?, _ tz: TimeZone) -> String {
        guard let d = d else { return "—" }
        let f = DateFormatter()
        f.timeZone = tz
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
}
