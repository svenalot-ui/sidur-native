import SwiftUI

@main
struct SidurApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(app)
        }
    }
}
