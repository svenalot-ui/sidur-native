import Foundation
import UserNotifications

// Per-zman reminder settings, persisted as JSON in UserDefaults.
struct ZmanReminder: Codable {
    var on: Bool
    var before: Int      // minutes before (0/5/10/15)
    var vk: String       // chosen variant key (e.g. "Tzais72")
}

enum Reminders {
    private static let key = "zmanReminders"

    static var all: [String: ZmanReminder] {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let d = try? JSONDecoder().decode([String: ZmanReminder].self, from: data) else { return [:] }
            return d
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    static func get(_ id: String) -> ZmanReminder? { all[id] }
    static func set(_ id: String, _ r: ZmanReminder) { var a = all; a[id] = r; all = a }
}

// Schedules local notifications for the next 7 days — they fire with the app closed.
enum NotificationScheduler {
    static func requestAuth() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional: return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default: return false
        }
    }

    @MainActor
    static func reschedule(app: AppState) {
        let enabled = Reminders.all.filter { $0.value.on }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard !enabled.isEmpty else { return }

        let lang = app.lang
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = app.tz
        let now = Date()

        for off in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: off, to: now) else { continue }
            // today: myzmanim-merged; future days: native engine (values match to the minute)
            let z = off == 0 ? app.currentZmanim : app.zmanim(for: day)
            let rows = z.rows()
            for (id, r) in enabled {
                guard let row = rows.first(where: { $0.id == id }) else { continue }
                guard let t = z.t(r.vk) ?? row.main else { continue }
                let fireAt = t.addingTimeInterval(-Double(r.before) * 60)
                guard fireAt > now.addingTimeInterval(30) else { continue }

                let content = UNMutableNotificationContent()
                content.title = "Сидур · \(row.name(lang))"
                let timeStr = ZFmt.time(t, app.tz)
                content.body = r.before > 0
                    ? (lang == .he ? "בעוד \(r.before) דק׳ · \(timeStr)" : "через \(r.before) мин · \(timeStr)")
                    : timeStr
                content.sound = .default

                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireAt)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(identifier: "\(id)_\(off)", content: content, trigger: trigger))
            }
        }
    }
}
