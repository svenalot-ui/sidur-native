import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        // Native system tab bar → real Apple Liquid Glass on iOS 26.
        TabView(selection: $app.tab) {
            TodayView()
                .tabItem { Label(app.s.today, systemImage: "sun.max") }
                .tag(0)
            ZmanimView()
                .tabItem { Label(app.s.zmanim, systemImage: "clock") }
                .tag(1)
            PrayersView()
                .tabItem { Label(app.s.prayers, systemImage: "book") }
                .tag(2)
            BrachotView()
                .tabItem { Label(app.s.brachot, systemImage: "leaf") }
                .tag(3)
            ScreenStub(title: app.s.tehillim, symbol: "star")
                .tabItem { Label(app.s.tehillim, systemImage: "star") }
                .tag(4)
        }
        .tint(Palette.gold)
        .environment(\.layoutDirection, app.lang.layoutDirection)
        .preferredColorScheme(app.preferredScheme)
        .onAppear { app.startLocation() }
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
