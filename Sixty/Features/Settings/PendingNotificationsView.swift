#if DEBUG
import SwiftUI
import SwiftData
import UserNotifications
import SixtyCore

/// Debug builds only: what's scheduled, and a test reminder for checking
/// that notifications arrive with the app closed and that a tap opens the day.
struct PendingNotificationsView: View {
    @Environment(\.modelContext) private var context
    @State private var requests: [UNNotificationRequest] = []

    var body: some View {
        List {
            Section {
                Button("Send a test reminder in 1 minute") { Task { await sendTest() } }
                    .surfaceRow()
                Button("Reschedule now") {
                    NotificationScheduler.reschedule(in: context)
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        await load()
                    }
                }
                .surfaceRow()
            } footer: {
                Text("Lock the phone or close the app after sending the test. Tapping it should open today.")
            }

            Section {
                if requests.isEmpty {
                    Text("Nothing scheduled").foregroundStyle(Tokens.Colour.ink2).surfaceRow()
                }
                ForEach(requests, id: \.identifier) { request in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(request.content.title).font(Tokens.Font.headline)
                        Text(request.content.body).font(Tokens.Font.subheadline).foregroundStyle(Tokens.Colour.ink2)
                        Text("\(fireDate(request)) · \(request.identifier)")
                            .font(Tokens.Font.caption2.monospaced())
                            .foregroundStyle(Tokens.Colour.ink3)
                    }
                    .padding(.vertical, Tokens.Space.xxs)
                    .surfaceRow()
                }
            } header: {
                Text("\(requests.count) pending").sectionLabelStyle()
            }
        }
        .sixtyListStyle()
        .navigationTitle("Notifications")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        requests = await NotificationScheduler.pending()
    }

    private func fireDate(_ request: UNNotificationRequest) -> String {
        guard let date = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                ?? (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() else { return "–" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }

    private func sendTest() async {
        await NotificationScheduler.requestPermission()
        let content = UNMutableNotificationContent()
        content.title = "Test reminder"
        content.body = "Tap to open today's log."
        content.sound = .default
        content.userInfo = [NotificationScheduler.dayKeyInfo: DayKey.today().rawValue]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        try? await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: "test", content: content, trigger: trigger))
        await load()
    }
}
#endif
