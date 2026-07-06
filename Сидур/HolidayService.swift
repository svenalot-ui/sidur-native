import Foundation

// Yom Tov days (melacha is forbidden — the app rests, like on Shabbat).
// Dates come from Hebcal with the correct Israel/diaspora schedule and are
// cached in UserDefaults so the block also works offline.
actor HolidayService {
    static let shared = HolidayService()

    struct Day: Codable, Equatable {
        let date: String      // yyyy-MM-dd (civil date of the Yom Tov day, location tz)
        let title: String     // Hebcal English title, e.g. "Pesach VII"
        let hebrew: String    // "פסח ז׳"
    }

    private var memo: [String: [Day]] = [:]   // "2026-7-il" → days of that month

    /// Yom Tov days of the month containing `date` plus the next month
    /// (a chag can straddle the boundary; Rosh Hashana eve is in Elul).
    func yomTovDays(around date: Date, tz: TimeZone, israel: Bool) async -> [Day] {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        var out: [Day] = []
        var comps = cal.dateComponents([.year, .month], from: date)
        for _ in 0..<2 {
            if let y = comps.year, let m = comps.month {
                out += await month(year: y, month: m, israel: israel)
            }
            if let cur = cal.date(from: comps),
               let nxt = cal.date(byAdding: .month, value: 1, to: cur) {
                comps = cal.dateComponents([.year, .month], from: nxt)
            }
        }
        return out
    }

    private func month(year: Int, month: Int, israel: Bool) async -> [Day] {
        let key = "\(year)-\(month)-\(israel ? "il" : "dia")"
        if let m = memo[key] { return m }
        let storeKey = "yomtov_\(key)"

        // network first (fills the cache), stored copy as offline fallback
        if let days = await fetch(year: year, month: month, israel: israel) {
            memo[key] = days
            if let d = try? JSONEncoder().encode(days) {
                UserDefaults.standard.set(d, forKey: storeKey)
            }
            return days
        }
        if let d = UserDefaults.standard.data(forKey: storeKey),
           let days = try? JSONDecoder().decode([Day].self, from: d) {
            memo[key] = days
            return days
        }
        return []
    }

    private func fetch(year: Int, month: Int, israel: Bool) async -> [Day]? {
        let i = israel ? "on" : "off"
        guard let url = URL(string:
            "https://www.hebcal.com/hebcal?v=1&cfg=json&year=\(year)&month=\(month)&maj=on&i=\(i)") else { return nil }
        do {
            var req = URLRequest(url: url); req.timeoutInterval = 12
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let j = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = j["items"] as? [[String: Any]] else { return nil }
            return items.compactMap { it in
                guard (it["yomtov"] as? Bool) == true,
                      let t = it["title"] as? String,
                      let date = (it["date"] as? String)?.prefix(10) else { return nil }
                return Day(date: String(date), title: t, hebrew: (it["hebrew"] as? String) ?? t)
            }
        } catch { return nil }
    }

    /// Russian name for a Hebcal holiday title ("Pesach VII" → «Песах»).
    static func ruName(_ title: String) -> String {
        let map: [(String, String)] = [
            ("Rosh Hashana", "Рош а-Шана"),
            ("Yom Kippur", "Йом Кипур"),
            ("Sukkot", "Суккот"),
            ("Shmini Atzeret", "Шмини Ацерет"),
            ("Simchat Torah", "Симхат Тора"),
            ("Pesach", "Песах"),
            ("Shavuot", "Шавуот"),
        ]
        for (en, ru) in map where title.hasPrefix(en) { return ru }
        return title
    }

    /// Hebrew name without the day ordinal or year ("פסח ז׳" → "פסח", "ראש השנה 5787" → "ראש השנה").
    static func heName(_ hebrew: String) -> String {
        var s = hebrew
        for suffix in [" א׳", " ב׳", " ז׳", " ח׳"] where s.hasSuffix(suffix) {
            s = String(s.dropLast(suffix.count))
        }
        if let last = s.split(separator: " ").last, last.allSatisfy(\.isNumber) {
            s = String(s.dropLast(last.count + 1))
        }
        return s
    }
}
