import SwiftUI
import SwiftData

@main
struct SixtyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let container: ModelContainer
    @State private var saver: AutoSaver

    init() {
        do {
            container = try ModelContainer(for: Plan.self, Activity.self, Question.self, DayEntry.self)
        } catch {
            fatalError("Couldn't open the Sixty store: \(error)")
        }
        let context = container.mainContext
        let saver = AutoSaver(context: context)
        // Every save may change tonight's check-in, so redo the reminders.
        saver.onSaved = { NotificationScheduler.reschedule(in: context) }
        _saver = State(initialValue: saver)
        Tokens.applySystemAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(saver)
                .environment(appDelegate.router)
        }
        .modelContainer(container)
    }
}
