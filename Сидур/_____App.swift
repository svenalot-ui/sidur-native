import SwiftUI
import CoreText

@main
struct SidurApp: App {
    @StateObject private var app = AppState()

    init() {
        // Register bundled variable fonts (no Info.plist keys needed).
        for name in ["FrankRuhlLibre", "BodoniModa"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(app)
        }
    }
}
