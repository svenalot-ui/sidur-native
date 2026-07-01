import SwiftUI

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

// MARK: - Palette ("quiet luxury" — matches the PWA)
enum Palette {
    static let paper  = dyn(0xFAFAF9, 0x13110E)
    static let card   = dyn(0xFFFFFF, 0x1E1B16)
    static let cream  = dyn(0xF1EFEA, 0x262119)
    static let gold   = dyn(0xA16207, 0xCBA250)
    static let goldL  = dyn(0xBFA46F, 0x9C8350)
    static let ink    = dyn(0x1C1917, 0xF0EBE1)
    static let soft   = dyn(0x57534E, 0xA8A096)
    static let faint  = dyn(0xA8A29E, 0x6E6759)
    static let line   = dyn(0xE3DFD8, 0x322C23)
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

// MARK: - Typography (system fonts for now; bundle Bodoni/Frank Ruhl later)
enum Typo {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .serif) }
    static func serif(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font { .system(size: size, weight: w, design: .serif) }
    static func sans(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font { .system(size: size, weight: w) }
}

