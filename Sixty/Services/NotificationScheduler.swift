import Foundation
import SwiftData
import UserNotifications
import SixtyCore

/// Local reminders. Keeps a rolling 14 days scheduled (iOS allows 64
/// pending), rebuilt on every app open and after every save. Permission is
/// asked for after plan setup, not on first launch.
@MainActor
enum NotificationScheduler {
    nonisolated static let dayKeyInfo = "dayKey"

    /// Asks once; later calls return the stored answer without prompting.
    @discardableResult
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Replaces everything pending with the next two weeks of reminders.
    static func reschedule(in context: ModelContext, now: Date = Date()) {
        let store = EntryStore(context: context)
        let reminders = store.plan().map { plan(for: $0, store: store, now: now) } ?? []
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            center.removeAllPendingNotificationRequests()
            for reminder in reminders {
                try? await center.add(request(for: reminder))
            }
        }
    }

    /// Takes tonight's check-in off the moment a day is complete, without
    /// waiting for the next reschedule. Also clears it from the lock screen.
    static func dayCompleted(_ day: DayKey) {
        let id = PlannedReminder.identifier(.evening, day)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    /// What's pending, for the debug list in Settings.
    static func pending() async -> [UNNotificationRequest] {
        func fireDate(_ request: UNNotificationRequest) -> Date {
            (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
        }
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.sorted { fireDate($0) < fireDate($1) }
    }

    // MARK: Private

    private static func plan(for plan: Plan, store: EntryStore, now: Date) -> [PlannedReminder] {
        let today = DayKey(now)
        let todayState = store.entry(for: today).map { entry in
            ReminderPlanner.TodayState(
                progress: entry.progress,
                openTitles: entry.progress.openActivityIDs.compactMap { plan.activity(id: $0)?.title })
        }
        let settings = ReminderPlanner.Settings(morningMinutes: plan.morningReminderMinutes,
                                                eveningMinutes: plan.eveningReminderMinutes,
                                                weeklyPhotoWeekday: plan.weeklyPhotoWeekday,
                                                weeklyPhotoMinutes: plan.weeklyPhotoMinutes)
        let activities = plan.activeActivities
        return ReminderPlanner.plan(calendar: plan.calendar,
                                    planName: plan.name,
                                    settings: settings,
                                    activityCount: activities.count,
                                    leadActivity: ReminderPlanner.leadActivity(fromFirstActivityTitle: activities.first?.title),
                                    today: today,
                                    todayState: todayState,
                                    now: now)
    }

    private static func request(for reminder: PlannedReminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.message.title
        content.body = reminder.message.body
        content.sound = .default
        content.threadIdentifier = "sixty"
        content.userInfo = [dayKeyInfo: reminder.day.rawValue]
        // Wall-clock components, so the time holds across clock changes.
        let parts = DateComponents(year: reminder.day.year, month: reminder.day.month, day: reminder.day.day,
                                   hour: reminder.minutesAfterMidnight / 60,
                                   minute: reminder.minutesAfterMidnight % 60)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        return UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
    }
}
