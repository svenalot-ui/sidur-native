import SwiftUI

// Premium 6-tab bar: liquid-glass background, a sliding glass "lens" under the
// active tab, emphasised gold circles for Молитвы / Брахот, and slide-to-select
// (drag across without lifting the finger — mirrors the PWA).
struct MainTabBar: View {
    @Binding var selection: Int
    @EnvironmentObject var app: AppState
    @Environment(\.colorScheme) private var scheme

    private struct Item { let icon: String; let label: String; let emph: Bool }
    private var items: [Item] {
        [
            Item(icon: "sun.max", label: app.s.today, emph: false),
            Item(icon: "clock", label: app.s.zmanim, emph: false),
            Item(icon: "book", label: app.s.prayers, emph: true),
            Item(icon: "leaf", label: app.s.brachot, emph: true),
            Item(icon: "star", label: app.s.tehillim, emph: false),
            Item(icon: "ellipsis", label: app.s.more, emph: false),
        ]
    }

    var body: some View {
        GeometryReader { geo in
            let n = CGFloat(items.count)
            let itemW = geo.size.width / n
            ZStack(alignment: .leading) {
                // sliding glass lens
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(0.16) : Color.white.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(scheme == .dark ? 0.25 : 0.9), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    .frame(width: itemW - 8, height: 50)
                    .offset(x: CGFloat(selection) * itemW + 4)

                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                        tab(it, active: selection == i)
                            .frame(width: itemW)
                    }
                }
            }
            .frame(height: 58)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let i = min(items.count - 1, max(0, Int(v.location.x / itemW)))
                        if i != selection {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { selection = i }
                        }
                    }
            )
        }
        .frame(height: 58)
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(scheme == .dark ? 0.14 : 0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
        .padding(.horizontal, 12)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: selection)
    }

    @ViewBuilder
    private func tab(_ it: Item, active: Bool) -> some View {
        VStack(spacing: 3) {
            ZStack {
                if it.emph {
                    Circle()
                        .fill(active
                              ? AnyShapeStyle(LinearGradient(colors: [Palette.gold, Palette.goldL], startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(Palette.cream))
                        .overlay(Circle().strokeBorder(Palette.gold.opacity(active ? 0 : 0.3), lineWidth: 1.5))
                        .frame(width: 34, height: 34)
                        .shadow(color: active ? Palette.gold.opacity(0.35) : .clear, radius: 6, y: 3)
                }
                Image(systemName: it.icon)
                    .font(.system(size: it.emph ? 18 : 21, weight: .regular))
                    .foregroundStyle(iconColor(it, active: active))
                    .scaleEffect(active && !it.emph ? 1.18 : 1)
            }
            .frame(height: 34)
            Text(it.label)
                .font(.system(size: 9.5, weight: active ? .bold : .medium))
                .foregroundStyle(active ? Palette.gold : Palette.faint)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func iconColor(_ it: Item, active: Bool) -> Color {
        if it.emph { return active ? .white : Palette.gold }
        return active ? Palette.gold : Palette.faint
    }
}
