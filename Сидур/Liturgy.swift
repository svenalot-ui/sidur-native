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

    /// Real text is present. Empty entries are placeholders awaiting content.
    var ready: Bool { !textHe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    func name(_ lang: Lang) -> String { lang == .he ? he : ru }
}

// A drill-in folder of related blessings (перед едой, запахи, заповеди, особые).
struct LiturgyFolder: Identifiable, Codable {
    let id: String
    let ru: String
    let he: String
    let icon: String
    let items: [SacredText]
    func name(_ lang: Lang) -> String { lang == .he ? he : ru }
    var readyCount: Int { items.filter(\.ready).count }
}

// Content lives in Content/liturgy.json so real texts can be dropped in as data —
// no code changes. See КАК_ПРИСЛАТЬ_ТЕКСТЫ.md for the format.
enum Liturgy {
    private struct Content: Codable {
        let brachotOften: [SacredText]
        let brachotFolders: [LiturgyFolder]
        let personal: [SacredText]
        let havdalah: SacredText
    }

    private static let content: Content = {
        guard let url = Bundle.main.url(forResource: "liturgy", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let c = try? JSONDecoder().decode(Content.self, from: data) else {
            assertionFailure("liturgy.json missing or malformed")
            return Content(brachotOften: [], brachotFolders: [], personal: [],
                           havdalah: SacredText(id: "havdalah", ru: "Авдала", he: "הַבְדָּלָה",
                                                icon: "flame", textHe: "", textTranslit: nil, textRu: nil))
        }
        return c
    }()

    static var brachotOften: [SacredText] { content.brachotOften }
    static var brachotFolders: [LiturgyFolder] { content.brachotFolders }
    static var personal: [SacredText] { content.personal }
    static var havdalah: SacredText { content.havdalah }

    private static var allTexts: [SacredText] {
        content.brachotOften + content.brachotFolders.flatMap(\.items) + content.personal + [content.havdalah]
    }

    static func bracha(_ id: String) -> SacredText? {
        allTexts.first { $0.id == id }
    }
}
