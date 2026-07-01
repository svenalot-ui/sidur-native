import Foundation

// Tehillim structure + text sources (Sefaria Hebrew, Synodal Russian) with disk cache.
enum Teh {
    // The five books of Tehillim.
    static let books: [(from: Int, to: Int)] = [(1, 41), (42, 72), (73, 89), (90, 106), (107, 150)]
    static let bookNumerals = ["I", "II", "III", "IV", "V"]

    // 30-day reading cycle (day of Hebrew month → psalm range).
    static let dayRanges: [ClosedRange<Int>] = [
        1...9, 10...17, 18...22, 23...28, 29...34, 35...38, 39...43, 44...48, 49...54, 55...59,
        60...65, 66...68, 69...71, 72...76, 77...78, 79...82, 83...87, 88...89, 90...96, 97...103,
        104...105, 106...107, 108...112, 113...118, 119...119, 120...134, 135...139, 140...144, 145...150, 145...150,
    ]

    static func chapters(day: Int) -> [Int] {
        let d = min(max(day, 1), 30)
        return Array(dayRanges[d - 1])
    }

    // MARK: favorites
    private static let favKey = "tehFav"
    static var favorites: [Int] {
        get {
            let raw = UserDefaults.standard.array(forKey: favKey) ?? []
            return raw.compactMap { ($0 as? Int) ?? Int("\($0)") }
        }
        set { UserDefaults.standard.set(newValue.sorted(), forKey: favKey) }
    }
    static func toggleFav(_ n: Int) {
        var f = favorites
        if let i = f.firstIndex(of: n) { f.remove(at: i) } else { f.append(n) }
        favorites = f
    }

    // MARK: transliteration (same char map as the PWA)
    static func translit(_ s: String) -> String {
        let finals: [Character: String] = ["ך": "х", "ם": "м", "ן": "н", "ף": "ф", "ץ": "ц"]
        let base: [Character: String] = [
            "א": "", "ב": "в", "ג": "г", "ד": "д", "ה": "һ", "ו": "в", "ז": "з", "ח": "х",
            "ט": "т", "י": "й", "כ": "к", "ל": "л", "מ": "м", "נ": "н", "ס": "с", "ע": "",
            "פ": "п", "צ": "ц", "ק": "к", "ר": "р", "ש": "ш", "ת": "т", "׳": "'", "״": "\"", "־": "-",
        ]
        var out = ""
        for scalar in s.unicodeScalars {
            // strip nikud / teamim
            if (0x0591...0x05C7).contains(Int(scalar.value)) { continue }
            let ch = Character(scalar)
            out += finals[ch] ?? base[ch] ?? String(ch)
        }
        return out.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
    }
}

// Fetch + cache psalm texts.
actor TehTexts {
    static let shared = TehTexts()

    private var ruChapters: [[String]]? = nil

    private var cacheDir: URL {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tehillim", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private func stripHTML(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        out = out.replacingOccurrences(of: "&[a-z]+;", with: " ", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespaces)
    }

    /// Hebrew verses for psalm `n` — cache-first, then Sefaria.
    func hebrew(_ n: Int) async -> [String]? {
        let f = cacheDir.appendingPathComponent("he_\(n).json")
        if let data = try? Data(contentsOf: f),
           let lines = try? JSONDecoder().decode([String].self, from: data) { return lines }
        guard let url = URL(string: "https://www.sefaria.org/api/texts/Psalms.\(n)?context=0") else { return nil }
        do {
            var req = URLRequest(url: url); req.timeoutInterval = 12
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let j = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let he = j["he"] as? [String] else { return nil }
            let lines = he.map { stripHTML($0) }
            if let enc = try? JSONEncoder().encode(lines) { try? enc.write(to: f) }
            return lines
        } catch { return nil }
    }

    /// Russian (Synodal) verses for psalm `n` — one bulk file, cached.
    func russian(_ n: Int) async -> [String]? {
        if ruChapters == nil {
            let f = cacheDir.appendingPathComponent("ru_all.json")
            if let data = try? Data(contentsOf: f),
               let ch = try? JSONDecoder().decode([[String]].self, from: data) {
                ruChapters = ch
            } else if let url = URL(string: "https://raw.githubusercontent.com/maatheusgois/bible/main/versions/ru/synodal/ps/ps.json") {
                do {
                    var req = URLRequest(url: url); req.timeoutInterval = 20
                    let (data, _) = try await URLSession.shared.data(for: req)
                    if let j = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let ch = j["chapters"] as? [[String]] {
                        ruChapters = ch
                        if let enc = try? JSONEncoder().encode(ch) { try? enc.write(to: cacheDir.appendingPathComponent("ru_all.json")) }
                    }
                } catch {}
            }
        }
        guard let ch = ruChapters, n - 1 < ch.count else { return nil }
        return ch[n - 1]
    }
}
