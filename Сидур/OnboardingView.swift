import SwiftUI

// First launch: choose the prayer nusach (siddur-cover style).
struct OnboardingView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Space.md) {
                Spacer()

                MagenDavid()
                    .stroke(Palette.gold, lineWidth: 1.6)
                    .frame(width: 44, height: 44)

                Text("שֶׁבֶת אַחִים גַּם יָחַד")
                    .font(Typo.serif(24))
                    .foregroundStyle(Palette.gold)

                Text(app.s.onbTitle)
                    .font(displayFont(26, app.lang))
                    .foregroundStyle(Palette.ink)
                Text(app.s.onbSub)
                    .font(Typo.sans(13))
                    .foregroundStyle(Palette.soft)

                VStack(spacing: 0) {
                    ForEach(Array(Nusach.allCases.enumerated()), id: \.element.rawValue) { idx, n in
                        Button {
                            app.nusach = n.rawValue
                        } label: {
                            HStack {
                                Text(n.name(app.lang))
                                    .font(Typo.sans(15.5, .medium))
                                    .foregroundStyle(Palette.ink)
                                Spacer(minLength: 0)
                                if app.lang != .he {
                                    Text(n.name(.he)).font(Typo.serif(16)).foregroundStyle(Palette.faint)
                                }
                            }
                            .padding(.horizontal, 20).padding(.vertical, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .top) {
                            if idx != 0 { Rectangle().fill(Palette.line).frame(height: 1) }
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 20).fill(Palette.card)
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.line, lineWidth: 1)))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.top, Space.sm)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 30)
        }
        .environment(\.layoutDirection, app.lang.layoutDirection)
    }
}
