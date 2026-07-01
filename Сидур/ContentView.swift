import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.paper.ignoresSafeArea()

            currentScreen
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 62) }

            MainTabBar(selection: $app.tab)
        }
        .tint(Palette.gold)
        .environment(\.layoutDirection, app.lang.layoutDirection)
        .preferredColorScheme(app.preferredScheme)
        .onAppear { app.startLocation() }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch app.tab {
        case 0: TodayView()
        case 1: ZmanimView()
        case 2: PrayersView()
        case 3: BrachotView()
        case 4: ScreenStub(title: app.s.tehillim, symbol: "star")
        default: ScreenStub(title: app.s.more, symbol: "ellipsis")
        }
    }
}

// Temporary placeholder for screens ported in later sessions.
struct ScreenStub: View {
    @EnvironmentObject var app: AppState
    let title: String
    let symbol: String

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            VStack(spacing: Space.md) {
                Image(systemName: symbol)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Palette.gold)
                Text(title)
                    .font(Typo.display(26))
                    .foregroundStyle(Palette.ink)
                Text(app.lang == .he ? "בקרוב" : "скоро")
                    .font(Typo.sans(14))
                    .foregroundStyle(Palette.faint)
            }
        }
    }
}
