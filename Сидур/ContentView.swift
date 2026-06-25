import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        TabView(selection: $app.tab) {
            TodayView()
                .tabItem { Label(app.s.today, systemImage: "sun.max") }
                .tag(0)
            ZmanimView()
                .tabItem { Label(app.s.zmanim, systemImage: "clock") }
                .tag(1)
            ScreenStub(title: app.s.prayers, symbol: "book")
                .tabItem { Label(app.s.prayers, systemImage: "book") }
                .tag(2)
            ScreenStub(title: app.s.brachot, symbol: "leaf")
                .tabItem { Label(app.s.brachot, systemImage: "leaf") }
                .tag(3)
            ScreenStub(title: app.s.tehillim, symbol: "star.of.david")
                .tabItem { Label(app.s.tehillim, systemImage: "star") }
                .tag(4)
            ScreenStub(title: app.s.more, symbol: "ellipsis")
                .tabItem { Label(app.s.more, systemImage: "ellipsis") }
                .tag(5)
        }
        .tint(Palette.gold)
        .environment(\.layoutDirection, app.lang.layoutDirection)
        .preferredColorScheme(app.preferredScheme)
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
