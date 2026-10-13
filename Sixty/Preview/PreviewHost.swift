import SwiftUI
import SwiftData
import SixtyCore

/// Wraps a preview in the sample data: model container, auto-saver and a
/// pinned "today" (Day 14 by default).
@MainActor
struct PreviewHost<Content: View>: View {
    private let container: ModelContainer
    private let today: DayKey
    private let content: (Plan) -> Content
    @State private var saver: AutoSaver
    @State private var router = AppRouter()

    init(today: DayKey = PreviewData.today, loggedThrough: Int = 13,
         @ViewBuilder content: @escaping (Plan) -> Content) {
        let container = PreviewData.container(loggedThrough: loggedThrough)
        self.container = container
        self.today = today
        self.content = content
        _saver = State(initialValue: AutoSaver(context: container.mainContext))
    }

    var body: some View {
        Group {
            if let plan = EntryStore(context: container.mainContext).plan() {
                content(plan)
            } else {
                Text("No sample plan")
            }
        }
        .modelContainer(container)
        .environment(saver)
        .environment(router)
        .environment(\.today, today)
    }
}
