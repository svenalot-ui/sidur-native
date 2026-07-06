import SwiftUI

// Reader backgrounds (self-contained "paper" ambiance, like an e-reader).
struct ReaderBG {
    let bg: Color, fg: Color
    static let all: [(key: String, bg: ReaderBG)] = [
        ("paper", ReaderBG(bg: Color(hex: 0xFBF3E0), fg: Color(hex: 0x2A2213))),
        ("sepia", ReaderBG(bg: Color(hex: 0xEFE2C7), fg: Color(hex: 0x4A3B22))),
        ("white", ReaderBG(bg: Color(hex: 0xFFFFFF), fg: Color(hex: 0x1C1917))),
        ("night", ReaderBG(bg: Color(hex: 0x15130F), fg: Color(hex: 0xE8E2D5))),
    ]
    static func get(_ key: String) -> ReaderBG { all.first { $0.key == key }?.bg ?? all[0].bg }
}

// Full-text reader for a bundled SacredText — offline. Options: language, size, background.
struct ReaderView: View {
    @EnvironmentObject var app: AppState
    let text: SacredText

    @AppStorage("rdrMode") private var mode: String = "he"        // he | translit | ru
    @AppStorage("rdrSize") private var size: Double = 23
    @AppStorage("rdrBg") private var bgKey: String = "paper"
    @State private var showSettings = false
    @State private var zen = false
    @State private var bookmarked = false

    private var palette: ReaderBG { ReaderBG.get(bgKey) }
    private var isRTL: Bool { mode == "he" }

    private var lines: [String] {
        let raw: String
        switch mode {
        case "ru": raw = text.textRu ?? text.textHe
        case "translit": raw = text.textTranslit ?? text.textHe
        default: raw = text.textHe
        }
        return raw.components(separatedBy: "\n")
    }

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                if !zen { langSegment }
                ScrollView {
                    VStack(alignment: isRTL ? .trailing : .leading, spacing: 16) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(mode == "he" ? Typo.serif(size) : Typo.sans(size - 4))
                                .foregroundStyle(palette.fg)
                                .lineSpacing(10)
                                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                                .multilineTextAlignment(isRTL ? .trailing : .leading)
                                .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                        }
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.lg)
                    .padding(.bottom, 110)
                }
            }
        }
        .readerChrome(title: text.name(app.lang), zen: $zen) {
            HStack(spacing: 6) {
                ReaderIconButton(symbol: bookmarked ? "bookmark.fill" : "bookmark", a11y: "Закладка", action: toggleBookmark)
                ReaderIconButton(symbol: "textformat.size", a11y: "Оформление текста") { showSettings = true }
            }
        }
        .sheet(isPresented: $showSettings) {
            ReaderOptionsSheet(size: $size, bgKey: $bgKey)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            bookmarked = Bookmarks.contains(kind: "text", refId: text.id)
            LastReadStore.save(kind: "text", refId: text.id, title: text.name(app.lang))
        }
    }

    private func toggleBookmark() {
        Bookmarks.toggle(Bookmark(kind: "text", refId: text.id, titleRu: text.ru, titleHe: text.he, icon: text.icon))
        bookmarked.toggle()
    }

    private var langSegment: some View {
        Segmented(items: [
            .init(label: app.s.he_, active: mode == "he") { mode = "he" },
            .init(label: app.s.translit, active: mode == "translit") { mode = "translit" },
            .init(label: app.s.ru_, active: mode == "ru") { mode = "ru" },
        ], ink: palette.fg, muted: palette.fg.opacity(0.5), baseline: palette.fg.opacity(0.18))
        .padding(.horizontal, Space.lg)
        .padding(.vertical, 12)
    }
}

extension SacredText {
    func name(_ lang: Lang) -> String { lang == .he ? he : ru }
}
