import SwiftUI

// Shared reader top bar + tap-anywhere-to-hide (zen) behavior, used by all three readers.
// Replaces the system navigation bar so it can fade away with the content still scrollable.
struct ReaderChromeModifier<Accessory: View>: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let title: String
    var tint: Color = Palette.ink        // reader foreground — keeps chrome legible on night paper
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

    // Quiet, floating chrome: a frosted round back button, a serif title, frosted
    // accessories — no heavy opaque band. A single hairline separates it from the text.
    private var topBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().strokeBorder(tint.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Назад")

            Text(title)
                .font(Typo.serif(18, .semibold))
                .foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)

            accessory()
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(tint.opacity(0.08)).frame(height: 1)
        }
    }
}

extension View {
    func readerChrome<A: View>(title: String, tint: Color = Palette.ink, zen: Binding<Bool>, @ViewBuilder accessory: @escaping () -> A) -> some View {
        modifier(ReaderChromeModifier(title: title, tint: tint, zen: zen, accessory: accessory))
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
                .frame(width: 36, height: 36)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().strokeBorder(tint.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11y ?? "")
    }
}

// Re-enables the interactive swipe-back gesture even when the navigation bar is
// hidden (SwiftUI otherwise disables it, so the readers lost edge-swipe to go back).
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
