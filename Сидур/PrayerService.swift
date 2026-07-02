import Foundation

// Weekday services, resolved per-nusach against Sefaria's siddur indexes.
enum ServiceKind: String {
    case shacharit, mincha, maariv
}

struct ServiceSection: Identifiable {
    let ref: String       // full Sefaria ref ("Siddur Ashkenaz, Weekday, Shacharit, …")
    let heTitle: String
    let enTitle: String
    var id: String { ref }
}

// Fetches siddur structure + section texts from Sefaria with a disk cache.
actor SiddurClient {
    static let shared = SiddurClient()

    // nusach → (index name, per-service node path from root)
    private func plan(for nusach: String) -> (index: String, paths: [ServiceKind: [String]]) {
        switch nusach {
        case "edot":
            return ("Siddur Edot HaMizrach",
                    [.shacharit: ["Weekday Shacharit"], .mincha: ["Weekday Mincha"], .maariv: ["Weekday Arvit"]])
        case "sefard", "chabad":   // Chabad → closest available on Sefaria
            return ("Siddur Sefard",
                    [.shacharit: ["Weekday Shacharit"], .mincha: ["Weekday Mincha"], .maariv: ["Weekday Maariv"]])
        default:
            return ("Siddur Ashkenaz",
                    [.shacharit: ["Weekday", "Shacharit"], .mincha: ["Weekday", "Minchah"], .maariv: ["Weekday", "Maariv"]])
        }
    }

    private var cacheDir: URL {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("siddur", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private func cachedData(_ name: String) -> Data? {
        try? Data(contentsOf: cacheDir.appendingPathComponent(name))
    }
    private func store(_ data: Data, _ name: String) {
        try? data.write(to: cacheDir.appendingPathComponent(name))
    }

    private func fetchJSON(_ urlStr: String, cacheName: String) async -> [String: Any]? {
        if let data = cachedData(cacheName),
           let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { return j }
        guard let url = URL(string: urlStr) else { return nil }
        do {
            var req = URLRequest(url: url); req.timeoutInterval = 15
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let j = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  j["error"] == nil else { return nil }
            store(data, cacheName)
            return j
        } catch { return nil }
    }

    private func urlRef(_ ref: String) -> String {
        let underscored = ref.replacingOccurrences(of: " ", with: "_")
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "_,-.()")
        return underscored.addingPercentEncoding(withAllowedCharacters: allowed) ?? underscored
    }

    /// Ordered leaf sections of a weekday service for the given nusach.
    func sections(nusach: String, service: ServiceKind) async -> [ServiceSection] {
        let p = plan(for: nusach)
        let indexName = p.index
        guard let path = p.paths[service] else { return [] }
        let idxURL = "https://www.sefaria.org/api/v2/index/\(urlRef(indexName))"
        guard let j = await fetchJSON(idxURL, cacheName: "index_\(indexName.replacingOccurrences(of: " ", with: "_")).json"),
              let schema = j["schema"] as? [String: Any] else { return [] }

        // descend to the service node
        var node: [String: Any]? = schema
        for step in path {
            let kids = (node?["nodes"] as? [[String: Any]]) ?? []
            node = kids.first { ($0["title"] as? String) == step }
        }
        guard let svcNode = node else { return [] }

        // DFS collect leaves with full ref path
        var out: [ServiceSection] = []
        func walk(_ n: [String: Any], refParts: [String]) {
            let title = (n["title"] as? String) ?? ""
            let parts = refParts + [title]
            let kids = (n["nodes"] as? [[String: Any]]) ?? []
            if kids.isEmpty {
                if title == "Modeh Ani" { return }   // removed per user preference
                out.append(ServiceSection(
                    ref: parts.joined(separator: ", "),
                    heTitle: (n["heTitle"] as? String) ?? title,
                    enTitle: title))
            } else {
                for k in kids { walk(k, refParts: parts) }
            }
        }
        // walk the service node itself (its title is the last path step)
        var base = [indexName]
        base.append(contentsOf: path.dropLast())
        walk(svcNode, refParts: base)
        return out
    }

    private func stripHTML(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        out = out.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        out = out.replacingOccurrences(of: "&[a-z#0-9]+;", with: " ", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func flatten(_ any: Any) -> [String] {
        if let s = any as? String { return [s] }
        if let arr = any as? [Any] { return arr.flatMap { flatten($0) } }
        return []
    }

    /// Hebrew paragraphs of one section (cache-first).
    func text(ref: String) async -> [String] {
        let cacheName = "t_" + ref.replacingOccurrences(of: "[^A-Za-z0-9]", with: "_", options: .regularExpression) + ".json"
        let url = "https://www.sefaria.org/api/texts/\(urlRef(ref))?context=0"
        guard let j = await fetchJSON(url, cacheName: cacheName) else { return [] }
        let raw = flatten(j["he"] ?? [])
        return raw.map { stripHTML($0) }.filter { !$0.isEmpty }
    }
}
