import SwiftUI

// Full-screen block shown during Shabbat or Yom Tov — the app rests. Calm, no navigation.
struct ShabbatView: View {
    @EnvironmentObject var app: AppState

    // Shabbat wording wins when Shabbat and a chag coincide.
    private var isChag: Bool { !app.isShabbat && app.currentYomTov != nil }

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()

                CandlesShape()
                    .stroke(Palette.gold, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 66, height: 66)

                Text(isChag ? "חַג שָׂמֵחַ" : "שַׁבָּת שָׁלוֹם")
                    .font(Typo.serif(36, .semibold))
                    .foregroundStyle(Palette.gold)
                    .padding(.top, 26)

                if app.lang != .he {
                    Text(isChag ? app.s.chagSameach : app.s.shabbatShalom)
                        .font(Typo.display(24))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 4)
                }

                if isChag, let yt = app.currentYomTov {
                    Text(app.lang == .he ? HolidayService.heName(yt.hebrew) : HolidayService.ruName(yt.title))
                        .font(Typo.serif(17))
                        .foregroundStyle(Palette.soft)
                        .padding(.top, 8)
                }

                Text(isChag ? app.s.chagResting : app.s.shabbatResting)
                    .font(Typo.sans(14))
                    .foregroundStyle(Palette.soft)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                    .padding(.horizontal, 40)

                if let end = app.restEndsAt {
                    VStack(spacing: 4) {
                        Text((isChag ? app.s.chagEndsAt : app.s.shabbatEndsAt).uppercased())
                            .font(Typo.label(10)).tracking(2)
                            .foregroundStyle(Palette.faint)
                        Text(app.fmt(end))
                            .font(Typo.digits(28))
                            .foregroundStyle(Palette.gold)
                            .monospacedDigit()
                    }
                    .padding(.top, 30)
                }

                Spacer()
                Spacer()

                // Deliberate high-friction escape for a wrong location / timezone.
                Button {
                    Haptics.tap()
                    app.bypassShabbat()
                } label: {
                    Text(isChag ? app.s.notChag : app.s.notShabbat)
                        .font(Typo.sans(12))
                        .foregroundStyle(Palette.faint)
                        .padding(10)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }
        }
        .environment(\.layoutDirection, app.lang.layoutDirection)
    }
}

// Two Shabbat candles with flames.
struct CandlesShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        func candle(_ cx: CGFloat) {
            let x = r.minX + cx
            let bodyTop = r.minY + h * 0.42
            let bodyBottom = r.maxY - h * 0.06
            let halfW = w * 0.075
            // body
            p.move(to: CGPoint(x: x - halfW, y: bodyTop))
            p.addLine(to: CGPoint(x: x - halfW, y: bodyBottom))
            p.addLine(to: CGPoint(x: x + halfW, y: bodyBottom))
            p.addLine(to: CGPoint(x: x + halfW, y: bodyTop))
            p.addLine(to: CGPoint(x: x - halfW, y: bodyTop))
            // flame (teardrop)
            let ft = r.minY + h * 0.14
            p.move(to: CGPoint(x: x, y: ft))
            p.addQuadCurve(to: CGPoint(x: x, y: bodyTop - h * 0.02),
                           control: CGPoint(x: x + halfW * 1.6, y: (ft + bodyTop) / 2))
            p.addQuadCurve(to: CGPoint(x: x, y: ft),
                           control: CGPoint(x: x - halfW * 1.6, y: (ft + bodyTop) / 2))
        }
        candle(w * 0.34)
        candle(w * 0.66)
        // base line
        p.move(to: CGPoint(x: r.minX + w * 0.18, y: r.maxY - h * 0.06))
        p.addLine(to: CGPoint(x: r.maxX - w * 0.18, y: r.maxY - h * 0.06))
        return p
    }
}
