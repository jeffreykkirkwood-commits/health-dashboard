import Foundation
import Combine
import UserNotifications

@MainActor final class ReminderManager: ObservableObject {
    @Published var message = "Notifications are off until you enable them."
    private let center = UNUserNotificationCenter.current()
    private var generation = 0
    func update(enabled: Bool, hour: Int, minute: Int) async {
        generation += 1
        let token = generation
        center.removePendingNotificationRequests(withIdentifiers: ["morning-review", "demo-test"])
        guard enabled else { message = "Muted. Pending reminders and demo tests removed."; return }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard token == generation else { return }
            guard granted else { message = "Notifications are disabled in iPhone Settings."; return }
            let content = UNMutableNotificationContent()
            content.title = "Your morning check-in"
            content.body = "Open Health Dashboard to sync and review your latest night."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
            try await center.add(UNNotificationRequest(identifier: "morning-review", content: content, trigger: trigger))
            guard token == generation else { center.removePendingNotificationRequests(withIdentifiers: ["morning-review"]); return }
            message = "One daily review reminder scheduled. Delivery may be delayed by system settings. This does not monitor sleep in the background."
        } catch { message = "Could not schedule the reminder. Please try again." }
    }
    func test(muted: Bool) async {
        guard !muted else { message = "Unmute reminders first to test."; return }
        let token = generation
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else { message = "Enable notifications in iPhone Settings first."; return }
            guard token == generation else { return }
            let content = UNMutableNotificationContent()
            content.title = "Synthetic demo notification"
            content.body = "This is a test, not a health alert."
            content.sound = .default
            try await center.add(UNNotificationRequest(identifier: "demo-test", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
            guard token == generation else { center.removePendingNotificationRequests(withIdentifiers: ["demo-test"]); return }
            message = "Test scheduled in 5 seconds. Put the app in the background to see the banner."
        } catch { message = "Notification test failed. Please retry." }
    }
}
