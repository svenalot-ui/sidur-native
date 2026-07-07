import SwiftUI

// Custom vector glyphs for icons that have no good SF Symbol (bread, fruit, etrog,
// challah, mezuzah, bun). Any name that isn't "g.*" falls back to an SF Symbol,
// so Glyph is a drop-in replacement for Image(systemName:).
struct Glyph: View {
    let name: String
    var size: CGFloat = 20
    var color: Color = Palette.gold

    var body: some View {
        if name.hasPrefix("g.") {
            Canvas { ctx, sz in Self.draw(name, &ctx, sz, color) }
                .frame(width: size * 1.15, height: size * 1.15)
        } else {
            Image(systemName: name).font(.system(size: size)).foregroundStyle(color)
        }
    }

    private static func draw(_ name: String, _ ctx: inout GraphicsContext, _ s: CGSize, _ color: Color) {
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s.width, y: y * s.height) }
        func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: x * s.width, y: y * s.height, width: w * s.width, height: h * s.height)
        }
        let paint = GraphicsContext.Shading.color(color)

        switch name {
        case "g.bread":
            var p = Path()
            p.move(to: P(0.09, 0.62))
            p.addCurve(to: P(0.91, 0.62), control1: P(0.11, 0.16), control2: P(0.89, 0.16))
            p.addLine(to: P(0.88, 0.70))
            p.addCurve(to: P(0.12, 0.70), control1: P(0.74, 0.82), control2: P(0.26, 0.82))
            p.closeSubpath()
            ctx.fill(p, with: paint)
            // score marks
            var sc = Path()
            for dx in stride(from: -0.18, through: 0.18, by: 0.18) {
                sc.move(to: P(0.5 + dx - 0.05, 0.30)); sc.addLine(to: P(0.5 + dx + 0.05, 0.46))
            }
            ctx.stroke(sc, with: .color(color.opacity(0.35)), lineWidth: s.width * 0.045)

        case "g.bun":
            var p = Path()
            p.move(to: P(0.12, 0.66))
            p.addCurve(to: P(0.88, 0.66), control1: P(0.16, 0.26), control2: P(0.84, 0.26))
            p.closeSubpath()
            ctx.fill(p, with: paint)
            ctx.fill(Path(roundedRect: R(0.12, 0.64, 0.76, 0.14), cornerRadius: s.width * 0.05), with: paint)
            for dx in [-0.16, 0.0, 0.16] {
                ctx.fill(Path(ellipseIn: R(0.47 + dx, 0.42, 0.06, 0.06)), with: .color(color.opacity(0.35)))
            }

        case "g.fruit":
            var p = Path()
            p.move(to: P(0.5, 0.30))
            p.addCurve(to: P(0.16, 0.56), control1: P(0.30, 0.28), control2: P(0.16, 0.40))
            p.addCurve(to: P(0.5, 0.92), control1: P(0.16, 0.80), control2: P(0.33, 0.92))
            p.addCurve(to: P(0.84, 0.56), control1: P(0.67, 0.92), control2: P(0.84, 0.80))
            p.addCurve(to: P(0.5, 0.30), control1: P(0.84, 0.40), control2: P(0.70, 0.28))
            ctx.fill(p, with: paint)
            var stem = Path(); stem.move(to: P(0.5, 0.30)); stem.addLine(to: P(0.55, 0.13))
            ctx.stroke(stem, with: paint, lineWidth: s.width * 0.05)
            var leaf = Path()
            leaf.move(to: P(0.55, 0.20))
            leaf.addQuadCurve(to: P(0.78, 0.16), control: P(0.68, 0.10))
            leaf.addQuadCurve(to: P(0.55, 0.20), control: P(0.66, 0.24))
            ctx.fill(leaf, with: paint)

        case "g.etrog":
            ctx.fill(Path(ellipseIn: R(0.27, 0.16, 0.46, 0.74)), with: paint)
            ctx.fill(Path(ellipseIn: R(0.44, 0.09, 0.12, 0.12)), with: paint)   // pitam
            var stalk = Path(); stalk.move(to: P(0.5, 0.10)); stalk.addLine(to: P(0.5, 0.03))
            ctx.stroke(stalk, with: paint, lineWidth: s.width * 0.04)

        case "g.challah":
            ctx.fill(Path(ellipseIn: R(0.12, 0.30, 0.58, 0.58)), with: paint)          // dough ball
            ctx.fill(Path(ellipseIn: R(0.66, 0.14, 0.24, 0.24)), with: paint)          // separated piece

        case "g.menorah":  // chanukiah — 9 candles with flames on an arm + base
            let arm = 0.56, top = 0.20
            ctx.fill(Path(R(0.10, arm, 0.80, 0.045)), with: paint)                     // horizontal arm
            ctx.fill(Path(R(0.47, arm, 0.06, 0.26)), with: paint)                      // central stem
            ctx.fill(Path(roundedRect: R(0.30, 0.82, 0.40, 0.07), cornerRadius: s.width * 0.02), with: paint)  // base
            let xs = stride(from: 0.14, through: 0.86, by: 0.09).map { $0 }
            for (i, x) in xs.enumerated() {
                let shamash = (i == 4)
                let candleTop = shamash ? top - 0.06 : top
                ctx.fill(Path(R(x - 0.012, candleTop, 0.024, arm - candleTop)), with: paint)   // candle
                ctx.fill(Path(ellipseIn: R(x - 0.028, candleTop - 0.075, 0.056, 0.075)), with: paint) // flame
            }

        case "g.mezuzah":
            let rect = R(0.34, 0.10, 0.32, 0.80)
            ctx.stroke(Path(roundedRect: rect, cornerRadius: s.width * 0.07), with: paint, lineWidth: s.width * 0.06)
            ctx.draw(Text("ש").font(.system(size: s.width * 0.30, weight: .semibold)).foregroundColor(color),
                     at: P(0.5, 0.5))

        default:
            break
        }
    }
}
