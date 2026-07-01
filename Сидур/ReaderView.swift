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
                langSegment
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
        .navigationTitle(text.name(app.lang))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "textformat.size").foregroundStyle(Palette.gold)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            ReaderOptionsSheet(size: $size, bgKey: $bgKey)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
    }

    private var langSegment: some View {
        HStack(spacing: 6) {
            seg("he", app.s.he_)
            seg("translit", app.s.translit)
            seg("ru", app.s.ru_)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, 12)
    }

    private func seg(_ key: String, _ label: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { mode = key } } label: {
            Text(label)
                .font(Typo.sans(13, mode == key ? .semibold : .regular))
                .foregroundStyle(mode == key ? .white : Palette.soft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(mode == key ? Palette.gold : Palette.card)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line, lineWidth: mode == key ? 0 : 1))
                )
        }
        .buttonStyle(.plain)
    }

}

extension SacredText {
    func name(_ lang: Lang) -> String { lang == .he ? he : ru }
}
