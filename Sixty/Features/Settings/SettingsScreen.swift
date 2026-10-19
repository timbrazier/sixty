import SwiftUI
import SwiftData
import UserNotifications
import SixtyCore

/// The Settings tab: plan details, reminders and export.
struct SettingsScreen: View {
    @Bindable var plan: Plan

    @Environment(\.modelContext) private var context
    @Environment(AutoSaver.self) private var saver
    @Query private var entries: [DayEntry]

    @State private var notificationsDenied = false
    @State private var shareURL: ShareItem?
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var photoBytes: Int64 = 0
    @State private var confirmReset = false

    struct ShareItem: Identifiable {
        let url: URL
        var id: URL { url }
    }

    var body: some View {
        NavigationStack {
            List {
                planSection
                remindersSection
                dataSection
                #if DEBUG
                Section {
                    NavigationLink("Pending notifications") { PendingNotificationsView() }
                        .surfaceRow()
                } header: {
                    Text("Debug").sectionLabelStyle()
                }
                #endif
                Section {
                    Button("End plan and start again", role: .destructive) { confirmReset = true }
                        .frame(minHeight: Tokens.Size.row)
                        .surfaceRow()
                } footer: {
                    Text("Deletes this plan, every day's log and all photos. Export first if you want to keep them.")
                        .font(Tokens.Font.footnoteRegular)
                }
            }
            .sixtyListStyle()
            .navigationTitle("Settings")
            .toolbarBackground(Tokens.Colour.bg, for: .navigationBar)
            .task { await refresh() }
            .sheet(item: $shareURL) { item in
                ShareSheet(items: [item.url])
                    .presentationDetents([.medium, .large])
            }
            .alert("Couldn't export", isPresented: Binding(get: { exportError != nil },
                                                          set: { if !$0 { exportError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "")
            }
            .confirmationDialog("End \(plan.name)?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Delete Plan, Logs and Photos", role: .destructive, action: resetPlan)
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    // MARK: Plan

    private var planSection: some View {
        Section {
            AdaptiveStack {
                Text("Name").foregroundStyle(Tokens.Colour.ink)
                TextField("Name", text: $plan.name)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Tokens.Colour.ink2)
                    .submitLabel(.done)
                    .onChange(of: plan.name) { _, _ in saver.changed() }
            }
            .frame(minHeight: Tokens.Size.row)
            .surfaceRow()

            NavigationLink { DatesEditor(plan: plan) } label: {
                row("Dates", value: "\(shortDate(plan.startDay)) – \(shortDate(plan.calendar.endDay))")
            }
            .surfaceRow()
            NavigationLink { ActivitiesEditor(plan: plan) } label: {
                row("Activities", value: plan.bonusActivities.isEmpty
                    ? "\(plan.coreActivities.count)"
                    : "\(plan.coreActivities.count) + \(plan.bonusActivities.count) bonus")
            }
            .surfaceRow()
            NavigationLink { QuestionsEditor(plan: plan) } label: {
                row("Daily questions", value: "\(plan.activeQuestions.count)")
            }
            .surfaceRow()
        } header: {
            Text("Plan").sectionLabelStyle()
        }
    }

    // MARK: Reminders

    private var remindersSection: some View {
        Section {
            ReminderRow(title: "Morning nudge",
                        isOn: reminderOn(\.morningReminderMinutes, default: 6 * 60 + 45),
                        minutes: reminderMinutes(\.morningReminderMinutes))
                .surfaceRow()
            ReminderRow(title: "Evening check-in",
                        isOn: reminderOn(\.eveningReminderMinutes, default: 21 * 60),
                        minutes: reminderMinutes(\.eveningReminderMinutes))
                .surfaceRow()
            ReminderRow(title: "Photo days",
                        isOn: reminderOn(\.weeklyPhotoMinutes, default: 7 * 60),
                        minutes: reminderMinutes(\.weeklyPhotoMinutes))
                .surfaceRow()
        } header: {
            Text("Reminders").sectionLabelStyle()
        } footer: {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("The evening check-in is skipped on days you've already completed. Photo days are Day 1 and every 10th day.")
                if notificationsDenied {
                    Text("Notifications are turned off for Sixty.")
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundStyle(Tokens.Colour.accent)
                }
            }
            .font(Tokens.Font.footnoteRegular)
        }
    }

    private func reminderOn(_ keyPath: ReferenceWritableKeyPath<Plan, Int?>, default minutes: Int) -> Binding<Bool> {
        Binding {
            plan[keyPath: keyPath] != nil
        } set: { isOn in
            plan[keyPath: keyPath] = isOn ? minutes : nil
            reminderChanged(turnedOn: isOn)
        }
    }

    private func reminderMinutes(_ keyPath: ReferenceWritableKeyPath<Plan, Int?>) -> Binding<Int> {
        Binding {
            plan[keyPath: keyPath] ?? 7 * 60
        } set: { minutes in
            guard plan[keyPath: keyPath] != nil else { return }
            plan[keyPath: keyPath] = minutes
            reminderChanged(turnedOn: false)
        }
    }

    /// Saving reschedules; turning a reminder on also asks for permission
    /// if it hasn't been asked yet.
    private func reminderChanged(turnedOn: Bool) {
        saver.changed()
        if turnedOn {
            Task {
                await NotificationScheduler.requestPermission()
                await refresh()
            }
        }
    }

    // MARK: Data

    private var dataSection: some View {
        let photoCount = entries.filter { $0.photoFilename != nil }.count
        return Section {
            Button {
                export { try Exporter.csv(in: context) }
            } label: {
                Text("Export log as CSV").frame(maxWidth: .infinity, minHeight: Tokens.Size.row, alignment: .leading)
            }
            .foregroundStyle(Tokens.Colour.accent)
            .surfaceRow()

            Button {
                export { try await Exporter.photosZip(in: context) }
            } label: {
                AdaptiveStack {
                    Text("Export photos").foregroundStyle(Tokens.Colour.accent)
                    AdaptiveSpacer()
                    if isExporting {
                        ProgressView()
                    } else {
                        Text("\(photoCount) · \(ByteCountFormatter.string(fromByteCount: photoBytes, countStyle: .file))")
                            .foregroundStyle(Tokens.Colour.ink2)
                    }
                }
                .frame(minHeight: Tokens.Size.row)
            }
            .disabled(photoCount == 0 || isExporting)
            .surfaceRow()
        } header: {
            Text("Data").sectionLabelStyle()
        } footer: {
            Text("Everything stays on this iPhone and in its backups. The CSV has one row per day; photos come as a zip named by day.")
                .font(Tokens.Font.footnoteRegular)
        }
    }

    private func export(_ make: @escaping () async throws -> URL) {
        saver.saveNow()
        isExporting = true
        Task {
            defer { isExporting = false }
            do {
                shareURL = ShareItem(url: try await make())
            } catch {
                exportError = error.localizedDescription
            }
        }
    }

    // MARK: Helpers

    private func row(_ title: String, value: String) -> some View {
        AdaptiveStack {
            Text(title).foregroundStyle(Tokens.Colour.ink)
            AdaptiveSpacer()
            Text(value).foregroundStyle(Tokens.Colour.ink2)
        }
        .frame(minHeight: Tokens.Size.row)
    }

    /// "30 Sep"
    private func shortDate(_ day: DayKey) -> String {
        day.startDate().formatted(.dateTime.day().month(.abbreviated))
    }

    private func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsDenied = settings.authorizationStatus == .denied
        photoBytes = await Task.detached { PhotoStore.totalBytes() }.value
    }

    /// Deletes everything; the root view then shows plan setup again.
    private func resetPlan() {
        try? context.delete(model: DayEntry.self)
        context.delete(plan)
        try? context.save()
        try? FileManager.default.removeItem(at: PhotoStore.directory)
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}

/// UIKit's share sheet, for files made on demand.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview("Settings") {
    PreviewHost { plan in SettingsScreen(plan: plan) }
}
