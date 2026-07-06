import Foundation

// All sacred texts are bundled in-app (offline from first launch — no network).
struct SacredText: Identifiable, Codable {
    let id: String
    let ru: String        // name (ru)
    let he: String        // name (he)
    let icon: String      // SF Symbol
    let textHe: String
    let textTranslit: String?
    let textRu: String?
}

// Content lives in Content/liturgy.json so real texts can be dropped in as data —
// no code changes. See КАК_ПРИСЛАТЬ_ТЕКСТЫ.md for the format.
enum Liturgy {
    private struct Content: Codable {
        let brachotOften: [SacredText]
        let brachotBefore: [SacredText]
        let brachotAfter: [SacredText]
        let personal: [SacredText]
    }

    private static let content: Content = {
        guard let url = Bundle.main.url(forResource: "liturgy", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let c = try? JSONDecoder().decode(Content.self, from: data) else {
            assertionFailure("liturgy.json missing or malformed")
            return Content(brachotOften: [], brachotBefore: [], brachotAfter: [], personal: [])
        }
        return c
    }()

    static var brachotOften: [SacredText] { content.brachotOften }
    static var brachotBefore: [SacredText] { content.brachotBefore }
    static var brachotAfter: [SacredText] { content.brachotAfter }
    static var personal: [SacredText] { content.personal }

    static func bracha(_ id: String) -> SacredText? {
        (brachotOften + brachotBefore + brachotAfter + personal).first { $0.id == id }
    }
}
