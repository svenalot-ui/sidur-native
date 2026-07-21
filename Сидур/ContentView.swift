import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.scenePhase) private var scenePhase
    private let minuteTick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

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
            TehillimView()
                .tabItem { Label(app.s.tehillim, systemImage: "star") }
                .tag(4)
        }
        .tint(Palette.gold)
        .environment(\.layoutDirection, app.lang.layoutDirection)
        .preferredColorScheme(app.preferredScheme)
        .onAppear {
            app.refreshZmanim()   // GPS is opt-in now; use the saved/selected city
            NotificationScheduler.reschedule(app: app)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                app.refreshZmanim()
                NotificationScheduler.reschedule(app: app)
            }
        }
        .onReceive(minuteTick) { _ in
            app.objectWillChange.send()   // re-evaluate auto theme + "now" prayer state
        }
        .onReceive(NotificationCenter.default.publisher(for: .sidurOpenZmanim)) { _ in
            app.tab = 1   // a zman notification was tapped
        }
        .fullScreenCover(isPresented: Binding(
            get: { app.nusach == nil },
            set: { _ in }
        )) {
            OnboardingView()
        }
        .overlay {
            if shabbatActive {
                ShabbatView()
                    .transition(.opacity)
            }
        }
    }

    private var shabbatActive: Bool {
        #if DEBUG
        if CommandLine.arguments.contains("-forceShabbat") { return true }
        #endif
        return app.isResting && !app.shabbatBypassed
    }
}
