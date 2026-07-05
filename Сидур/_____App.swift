import SwiftUI
import CoreText
import UserNotifications

extension Notification.Name {
    static let sidurOpenZmanim = Notification.Name("sidurOpenZmanim")
}

// Shows zman banners while the app is open; tapping a notification opens the Zmanim tab.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        await MainActor.run {
            NotificationCenter.default.post(name: .sidurOpenZmanim, object: nil)
        }
    }
}

@main
struct SidurApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var app = AppState()

    init() {
        // Register bundled variable fonts (no Info.plist keys needed).
        for name in ["FrankRuhlLibre", "BodoniModa", "PlayfairDisplay"] {
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
