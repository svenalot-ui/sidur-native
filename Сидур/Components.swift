import SwiftUI

// Masks the status-bar safe area with the page color so scrolled content
// never collides with the clock (screens use a custom in-scroll serif title).
extension View {
    func statusBarMask() -> some View {
        overlay(alignment: .top) {
            GeometryReader { geo in
                Rectangle().fill(Palette.paper)
                    .frame(height: geo.safeAreaInsets.top)
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea(edges: .top)
            }
            .allowsHitTesting(false)
        }
    }
}

// A large editorial screen title — Playfair for RU/Latin, Frank Ruhl for Hebrew.
struct ScreenTitle: View {
    @EnvironmentObject var app: AppState
    let text: String
    var body: some View {
        Text(text)
            .font(displayFont(30, app.lang))
            .foregroundStyle(Palette.ink)
            .lineLimit(1).minimumScaleFactor(0.6)
    }
}

// Premium segmented control: a single unified track with an active pill that
// slides between options — replaces the loose bordered pills that looked cheap.
struct Segmented: View {
    struct Item: Identifiable {
        let id = UUID()
        let label: String
        let active: Bool
        let action: () -> Void
    }
    let items: [Item]
    // Colors are overridable so the control works on a reader's paper/sepia/night background.
    var ink: Color = Palette.ink
    var muted: Color = Palette.soft
    var accent: Color = Palette.gold
    var baseline: Color = Palette.line

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { it in
                Button {
                    Haptics.tap()
                    withAnimation(.easeInOut(duration: 0.18)) { it.action() }
                } label: {
                    Text(it.label)
                        .font(Typo.sans(14, it.active ? .semibold : .regular))
                        .foregroundStyle(it.active ? ink : muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(it.active ? accent : baseline)
                                .frame(height: it.active ? 2 : 1)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// Editorial single-select row (used for nusach) — clearer than a grid of pills.
struct SelectRow: View {
    let label: String
    var sub: String? = nil
    let active: Bool
    let first: Bool
    let action: () -> Void

    var body: some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 12) {
                Text(label)
                    .font(Typo.sans(15.5, active ? .semibold : .regular))
                    .foregroundStyle(Palette.ink)
                if let sub {
                    Text(sub).font(Typo.serif(15)).foregroundStyle(Palette.faint)
                }
                Spacer(minLength: 8)
                if active {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.gold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if !first { Rectangle().fill(Palette.line).frame(height: 1).padding(.leading, 16) }
        }
    }
}
