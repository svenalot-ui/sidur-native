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

    @AppStorage("rdrMode") private var storedMode: String = "he"  // he | translit | ru
    @AppStorage("rdrSize") private var size: Double = 23
    @AppStorage("rdrBg") private var bgKey: String = "paper"
    @State private var showSettings = false
    @State private var zen = false
    @State private var bookmarked = false
    @State private var scrollPos: Int?

    // On a Hebrew interface the transliteration/translation toggle is unnecessary.
    private var showLangToggle: Bool { app.lang != .he }
    private var mode: String { showLangToggle ? storedMode : "he" }

    private var palette: ReaderBG { ReaderBG.get(bgKey) }
    private var isRTL: Bool { mode == "he" }
    private var posKey: String { "text_\(text.id)" }

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
                if !zen && showLangToggle { langSegment }
                ScrollView {
                    VStack(alignment: isRTL ? .trailing : .leading, spacing: 16) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(mode == "he" ? Typo.serif(size) : Typo.sans(size - 4))
                                .foregroundStyle(palette.fg)
                                .lineSpacing(10)
                                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                                .multilineTextAlignment(isRTL ? .trailing : .leading)
                                .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                                .id(idx)
                        }
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.lg)
                    .padding(.bottom, 110)
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $scrollPos, anchor: .top)
            }
        }
        .readerChrome(title: text.name(app.lang), tint: palette.fg, zen: $zen) {
            HStack(spacing: 6) {
                ReaderIconButton(symbol: bookmarked ? "bookmark.fill" : "bookmark", tint: palette.fg, a11y: "Закладка", action: toggleBookmark)
                ReaderIconButton(symbol: "textformat.size", tint: palette.fg, a11y: "Оформление текста") { showSettings = true }
            }
        }
        .sheet(isPresented: $showSettings) {
            ReaderOptionsSheet(size: $size, bgKey: $bgKey)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: scrollPos) { _, new in
            if let new { ReadPos.save(posKey, new) }
        }
        .onAppear {
            bookmarked = Bookmarks.contains(kind: "text", refId: text.id)
            LastReadStore.save(kind: "text", refId: text.id, title: text.name(app.lang))
            if let saved = ReadPos.get(posKey), saved < lines.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { scrollPos = saved }
            }
        }
    }

    private func toggleBookmark() {
        Bookmarks.toggle(Bookmark(kind: "text", refId: text.id, titleRu: text.ru, titleHe: text.he, icon: text.icon))
        bookmarked.toggle()
    }

    private var langSegment: some View {
        Segmented(items: [
            .init(label: app.s.he_, active: mode == "he") { storedMode = "he" },
            .init(label: app.s.translit, active: mode == "translit") { storedMode = "translit" },
            .init(label: app.s.ru_, active: mode == "ru") { storedMode = "ru" },
        ], ink: palette.fg, muted: palette.fg.opacity(0.5), baseline: palette.fg.opacity(0.18))
        .padding(.horizontal, Space.lg)
        .padding(.vertical, 12)
    }
}

extension SacredText {
    func name(_ lang: Lang) -> String { lang == .he ? he : ru }
}
