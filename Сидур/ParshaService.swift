import Foundation

// Weekly Torah portion — next upcoming "parashat" event from Hebcal, cached for offline.
actor ParshaService {
    static let shared = ParshaService()

    struct Parsha: Codable {
        let title: String     // "Parashat Pinchas"
        let hebrew: String    // "פרשת פינחס"
        let date: String      // yyyy-MM-dd of that Shabbat
    }

    private let storeKey = "parshaCache"
    private var memo: Parsha?

    /// Short display name without the "Parashat " prefix.
    static func shortTitle(_ p: Parsha) -> String {
        p.title.replacingOccurrences(of: "Parashat ", with: "")
    }

    /// Russian name of the weekly portion (handles combined parshiot like "Matot-Masei").
    static func ruName(_ p: Parsha) -> String {
        shortTitle(p)
            .split(separator: "-")
            .map { ruMap[$0.trimmingCharacters(in: .whitespaces)] ?? String($0) }
            .joined(separator: "-")
    }

    private static let ruMap: [String: String] = [
        "Bereshit": "Берешит", "Noach": "Ноах", "Lech-Lecha": "Лех-Леха", "Vayera": "Вайера",
        "Chayei Sara": "Хаей Сара", "Toldot": "Тольдот", "Vayetzei": "Вайеце", "Vayishlach": "Ваишлах",
        "Vayeshev": "Вайешев", "Miketz": "Микец", "Vayigash": "Ваигаш", "Vayechi": "Вайехи",
        "Shemot": "Шмот", "Vaera": "Ваэра", "Bo": "Бо", "Beshalach": "Бешалах", "Yitro": "Итро",
        "Mishpatim": "Мишпатим", "Terumah": "Трума", "Tetzaveh": "Тецаве", "Ki Tisa": "Ки Тиса",
        "Vayakhel": "Ваякъель", "Pekudei": "Пкудей", "Vayikra": "Ваикра", "Tzav": "Цав",
        "Shmini": "Шмини", "Tazria": "Тазриа", "Metzora": "Мецора", "Achrei Mot": "Ахарей Мот",
        "Kedoshim": "Кдошим", "Emor": "Эмор", "Behar": "Беар", "Bechukotai": "Бехукотай",
        "Bamidbar": "Бемидбар", "Nasso": "Насо", "Beha'alotcha": "Беаалотха", "Sh'lach": "Шлах",
        "Korach": "Корах", "Chukat": "Хукат", "Balak": "Балак", "Pinchas": "Пинхас",
        "Matot": "Матот", "Masei": "Масей", "Devarim": "Дварим", "Vaetchanan": "Ваэтханан",
        "Eikev": "Экев", "Re'eh": "Реэ", "Shoftim": "Шофтим", "Ki Teitzei": "Ки Теце",
        "Ki Tavo": "Ки Таво", "Nitzavim": "Ницавим", "Vayeilech": "Вайелех", "Ha'azinu": "Аазину",
        "Vezot Haberakhah": "Везот аБраха",
    ]

    func next() async -> Parsha? {
        let today = Self.ymd(Date())
        if let m = memo, m.date >= today { return m }

        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        var comps = cal.dateComponents([.year, .month], from: now)

        // Look in this month, then the next (Shabbat can fall across the boundary).
        for _ in 0..<2 {
            if let y = comps.year, let m = comps.month,
               let found = await fetchParsha(year: y, month: m, onOrAfter: today) {
                memo = found
                if let d = try? JSONEncoder().encode(found) {
                    UserDefaults.standard.set(d, forKey: storeKey)
                }
                return found
            }
            if let cur = cal.date(from: comps), let nxt = cal.date(byAdding: .month, value: 1, to: cur) {
                comps = cal.dateComponents([.year, .month], from: nxt)
            }
        }

        // Offline fallback — last stored value if it's still current.
        if let d = UserDefaults.standard.data(forKey: storeKey),
           let p = try? JSONDecoder().decode(Parsha.self, from: d),
           p.date >= today {
            memo = p
            return p
        }
        return nil
    }

    private func fetchParsha(year: Int, month: Int, onOrAfter: String) async -> Parsha? {
        guard let url = URL(string: "https://www.hebcal.com/hebcal?v=1&cfg=json&year=\(year)&month=\(month)&s=on") else { return nil }
        do {
            var req = URLRequest(url: url); req.timeoutInterval = 12
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let j = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = j["items"] as? [[String: Any]] else { return nil }
            let parshiot = items.compactMap { it -> Parsha? in
                guard (it["category"] as? String) == "parashat",
                      let t = it["title"] as? String,
                      let date = (it["date"] as? String)?.prefix(10) else { return nil }
                return Parsha(title: t, hebrew: (it["hebrew"] as? String) ?? "", date: String(date))
            }
            return parshiot.filter { $0.date >= onOrAfter }.min { $0.date < $1.date }
        } catch { return nil }
    }

    private static func ymd(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}
