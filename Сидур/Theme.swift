import SwiftUI
import CoreText

// MARK: - Color from hex
extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

private func dyn(_ light: UInt, _ dark: UInt) -> Color {
    Color(UIColor { tc in
        let v = tc.userInterfaceStyle == .dark ? dark : light
        return UIColor(
            red:   CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >> 8) & 0xFF) / 255,
            blue:  CGFloat(v & 0xFF) / 255,
            alpha: 1
        )
    })
}

// MARK: - Palette (E-ink / paper editorial — warm, high contrast, WCAG-AAA leaning)
// Gold is reserved for interaction + the one signature rule; content is ink on paper.
enum Palette {
    static let paper  = dyn(0xFCFAF5, 0x121010)
    static let card   = dyn(0xFFFFFF, 0x1C1A16)
    static let cream  = dyn(0xF2EEE6, 0x242019)
    static let gold   = dyn(0x986413, 0xCBA255)
    static let goldL  = dyn(0xB08A4A, 0x9C8350)
    static let ink    = dyn(0x1A1714, 0xF2EDE3)
    static let soft   = dyn(0x554E45, 0xAAA296)
    static let faint  = dyn(0x8A8175, 0x7C746A)
    static let line   = dyn(0xE6E0D5, 0x2E2820)
}

// MARK: - Liquid Glass (native iOS 26; falls back to material)
extension View {
    @ViewBuilder
    func liquidGlass<S: Shape>(_ shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}

// MARK: - Spacing
enum Space {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
}

// MARK: - Typography (editorial system)
// display: Playfair Display (Latin/Cyrillic display serif). serif: Frank Ruhl Libre (Hebrew).
// digits: Bodoni Moda (numerals). label: SF Mono for the uppercase micro-labels — the signature.
// Custom fonts scale with the user's Dynamic Type setting via relativeTo;
// the mono micro-labels stay fixed on purpose (uppercase kickers shouldn't balloon).
enum Typo {
    static func display(_ size: CGFloat) -> Font { .custom("Playfair Display", size: size, relativeTo: .title).weight(.semibold) }
    static func digits(_ size: CGFloat, _ w: Font.Weight = .semibold) -> Font { .custom("Bodoni Moda", size: size, relativeTo: .title).weight(w) }
    static func serif(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font { .custom("Frank Ruhl Libre", size: size, relativeTo: .body).weight(w) }
    static func sans(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font { .system(size: size, weight: w) }
    static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
}

// Display serif that respects script: Playfair for Latin/Cyrillic, Frank Ruhl for Hebrew.
func displayFont(_ size: CGFloat, _ lang: Lang) -> Font {
    lang == .he ? Typo.serif(size, .semibold) : Typo.display(size)
}

// Same as displayFont, but forces LINING figures so numerals share one baseline —
// Playfair's default oldstyle figures made the year digits (5,7 vs 8,6) jump.
func displayFontLining(_ size: CGFloat, _ lang: Lang) -> Font {
    if lang == .he { return Typo.serif(size, .semibold) }
    let base = UIFont(name: "Playfair Display", size: size) ?? .systemFont(ofSize: size, weight: .semibold)
    let desc = base.fontDescriptor.addingAttributes([
        .featureSettings: [[
            UIFontDescriptor.FeatureKey.type: kNumberCaseType,
            UIFontDescriptor.FeatureKey.selector: kUpperCaseNumbersSelector,
        ]],
        .traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.semibold.rawValue],
    ])
    return Font(UIFont(descriptor: desc, size: size))
}

