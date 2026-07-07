import Foundation
import UIKit

// MARK: - Continue Reading
struct LastRead: Codable, Equatable {
    let kind: String     // "text" | "psalm" | "service"
    let refId: String
    let title: String
    let ts: Date
}

enum LastReadStore {
    private static let key = "lastRead"
    static var current: LastRead? {
        get {
            guard let d = UserDefaults.standard.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(LastRead.self, from: d)
        }
        set {
            if let v = newValue, let d = try? JSONEncoder().encode(v) {
                UserDefaults.standard.set(d, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
    static func save(kind: String, refId: String, title: String) {
        current = LastRead(kind: kind, refId: refId, title: title, ts: Date())
    }
    static func dismiss() { current = nil }
}

// MARK: - Exact reading position (paragraph index per reader), so "Continue reading"
// returns to the exact place, not just the top of the section.
enum ReadPos {
    private static func k(_ key: String) -> String { "rpos_\(key)" }
    static func save(_ key: String, _ idx: Int) { UserDefaults.standard.set(idx, forKey: k(key)) }
    static func get(_ key: String) -> Int? {
        UserDefaults.standard.object(forKey: k(key)) as? Int
    }
}

// MARK: - Bookmarks (brachot / personal texts / services)
// Tehillim psalms keep their own store (Teh.favorites) — merged for display on Today.
struct Bookmark: Codable, Equatable, Identifiable {
    let kind: String     // "text" | "service"
    let refId: String
    let titleRu: String
    let titleHe: String
    let icon: String
    var id: String { "\(kind):\(refId)" }
    func title(_ lang: Lang) -> String { lang == .he ? titleHe : titleRu }
}

enum Bookmarks {
    private static let key = "bookmarksV2"
    static var all: [Bookmark] {
        get {
            guard let d = UserDefaults.standard.data(forKey: key) else { return [] }
            return (try? JSONDecoder().decode([Bookmark].self, from: d)) ?? []
        }
        set {
            if let d = try? JSONEncoder().encode(newValue) { UserDefaults.standard.set(d, forKey: key) }
        }
    }
    static func contains(kind: String, refId: String) -> Bool {
        all.contains { $0.kind == kind && $0.refId == refId }
    }
    static func toggle(_ b: Bookmark) {
        var a = all
        if let i = a.firstIndex(where: { $0.id == b.id }) { a.remove(at: i) } else { a.append(b) }
        all = a
    }
    static func remove(id: String) { all = all.filter { $0.id != id } }
    static func saveOrder(_ items: [Bookmark]) { all = items }
}

// MARK: - Programmatic navigation target (used by Today's resume banner + favorites)
enum Route: Hashable {
    case text(String)
    case psalm(Int)
    case service(String)      // ServiceKind.rawValue
    case tehillimDay(Int)     // day of the Hebrew month → that day's psalms
}

// MARK: - Haptics
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    /// Very soft tick — used repeatedly while the compass rotates.
    static func soft(_ intensity: CGFloat = 0.5) {
        let g = UIImpactFeedbackGenerator(style: .soft); g.impactOccurred(intensity: intensity)
    }
    /// A distinct, satisfying double-pulse — used when the compass locks onto Jerusalem.
    static func lock() {
        let g = UIImpactFeedbackGenerator(style: .rigid)
        g.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { g.impactOccurred(intensity: 0.7) }
    }
}
