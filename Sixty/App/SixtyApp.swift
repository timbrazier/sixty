import SwiftUI
import SwiftData

@main
struct SixtyApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Plan.self, Activity.self, Question.self, DayEntry.self)
        } catch {
            fatalError("Couldn't open the Sixty store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
