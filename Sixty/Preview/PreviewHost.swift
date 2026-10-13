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

    init(today: DayKey = PreviewData.today, @ViewBuilder content: @escaping (Plan) -> Content) {
        let container = PreviewData.container
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
        .environment(\.today, today)
    }
}
