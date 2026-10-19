import SwiftUI
import SwiftData
import SixtyCore

/// Plan setup until a plan exists, then the four tabs.
struct RootView: View {
    @Query(sort: \Plan.createdAt, order: .reverse) private var plans: [Plan]
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AutoSaver.self) private var saver
    @Environment(\.modelContext) private var context
    @State private var today: DayKey

    init(today: DayKey = .today()) {
        _today = State(initialValue: today)
    }

    var body: some View {
        Group {
            if let plan = plans.first {
                MainTabView(plan: plan)
            } else {
                PlanSetupView()
            }
        }
        .environment(\.today, today)
        .tint(Tokens.Colour.accent)
        .task { DataMigrations.run(in: context, today: today) }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                today = .today()
                NotificationScheduler.reschedule(in: context)
            // Don't wait out the 500 ms: the app may be killed in the background.
            case .inactive, .background: saver.saveNow()
            @unknown default: break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            today = .today()
            NotificationScheduler.reschedule(in: context)
        }
    }
}

struct MainTabView: View {
    let plan: Plan
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            TodayScreen(plan: plan)
                .tabItem { Label("Today", systemImage: "smallcircle.filled.circle") }
                .tag(AppRouter.Tab.today)
            ProgressScreen(plan: plan)
                .tabItem { Label("Progress", systemImage: "square.grid.2x2") }
                .tag(AppRouter.Tab.progress)
            PhotosScreen(plan: plan)
                .tabItem { Label("Photos", systemImage: "photo") }
                .tag(AppRouter.Tab.photos)
            SettingsScreen(plan: plan)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppRouter.Tab.settings)
        }
    }
}

#Preview("Day 14") {
    PreviewHost { _ in RootView(today: PreviewData.today) }
}

#Preview("No plan") {
    let container = PreviewData.emptyContainer
    return RootView()
        .modelContainer(container)
        .environment(AutoSaver(context: container.mainContext))
        .environment(AppRouter())
}
