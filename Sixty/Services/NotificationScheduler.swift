import Foundation
import UserNotifications

/// Local reminders. Permission is asked for after plan setup; the rolling
/// 14-day schedule arrives in step 7.
enum NotificationScheduler {
    /// Asks once; later calls return the stored answer without prompting.
    @discardableResult
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }
}
