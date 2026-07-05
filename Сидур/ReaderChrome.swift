import SwiftUI

// Shared reader top bar + tap-anywhere-to-hide (zen) behavior, used by all three readers.
// Replaces the system navigation bar so it can fade away with the content still scrollable.
struct ReaderChromeModifier<Accessory: View>: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var zen: Bool
    @ViewBuilder var accessory: () -> Accessory

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if !zen { topBar }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(zen ? .hidden : .visible, for: .tabBar)
            .animation(.easeInOut(duration: 0.25), value: zen)
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.tap()
                zen.toggle()
            }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Назад")

            Text(title)
                .font(Typo.sans(15, .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            accessory()
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
}

extension View {
    func readerChrome<A: View>(title: String, zen: Binding<Bool>, @ViewBuilder accessory: @escaping () -> A) -> some View {
        modifier(ReaderChromeModifier(title: title, zen: zen, accessory: accessory))
    }
}

// Small round icon button used in reader accessory rows.
struct ReaderIconButton: View {
    let symbol: String
    var filled: Bool = false
    var tint: Color = Palette.gold
    var a11y: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Circle().fill(.ultraThinMaterial))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11y ?? "")
    }
}
