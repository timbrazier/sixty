import SwiftUI
import SwiftData

@main
struct SixtyApp: App {
    let container: ModelContainer
    @State private var saver: AutoSaver

    init() {
        do {
            container = try ModelContainer(for: Plan.self, Activity.self, Question.self, DayEntry.self)
        } catch {
            fatalError("Couldn't open the Sixty store: \(error)")
        }
        _saver = State(initialValue: AutoSaver(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(saver)
        }
        .modelContainer(container)
    }
}
