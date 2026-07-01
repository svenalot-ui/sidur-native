import SwiftUI

// Full-text reader for a bundled SacredText. Language toggle he / translit / ru.
struct ReaderView: View {
    @EnvironmentObject var app: AppState
    let text: SacredText
    @State private var mode: String = "he"   // "he" | "translit" | "ru"

    private var body_lines: [String] {
        let raw: String
        switch mode {
        case "ru": raw = text.textRu ?? text.textHe
        case "translit": raw = text.textTranslit ?? text.textHe
        default: raw = text.textHe
        }
        return raw.components(separatedBy: "\n")
    }

    private var isRTL: Bool { mode == "he" }

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                segment
                ScrollView {
                    VStack(alignment: isRTL ? .trailing : .leading, spacing: 14) {
                        ForEach(Array(body_lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(mode == "he" ? Typo.serif(23) : Typo.sans(18))
                                .foregroundStyle(Palette.ink)
                                .lineSpacing(9)
                                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                                .multilineTextAlignment(isRTL ? .trailing : .leading)
                                .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                        }
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.lg)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle(text.name(app.lang))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var segment: some View {
        HStack(spacing: 6) {
            seg("he", app.lang == .he ? "עברית" : "Иврит")
            seg("translit", app.lang == .he ? "תעתיק" : "Транслит.")
            seg("ru", app.lang == .he ? "רוסית" : "Русский")
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, 12)
    }

    private func seg(_ key: String, _ label: String) -> some View {
        Button { mode = key } label: {
            Text(label)
                .font(Typo.sans(13))
                .foregroundStyle(mode == key ? .white : Palette.soft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
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
