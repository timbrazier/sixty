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
                .tabItem { Label("Today", systemImage: "circle.circle") }
                .tag(AppRouter.Tab.today)
            ProgressScreen(plan: plan)
                .tabItem { Label("Progress", systemImage: "square.grid.2x2") }
                .tag(AppRouter.Tab.progress)
            PhotosScreen(plan: plan)
                .tabItem { Label("Photos", systemImage: "photo") }
                .tag(AppRouter.Tab.photos)
            PlaceholderScreen(title: "Settings", plan: plan)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppRouter.Tab.settings)
        }
    }
}

// MARK: Placeholder until step 8 replaces it

private struct PlaceholderScreen: View {
    let title: String
    let plan: Plan
    @Environment(\.today) private var today

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Day").sectionLabelStyle()
                HStack(alignment: .lastTextBaseline, spacing: Tokens.Space.xxs) {
                    Text("\(plan.calendar.dayNumber(for: today))")
                        .font(Tokens.Font.bib())
                        .foregroundStyle(Tokens.Colour.ink)
                    Text("of \(plan.lengthDays)")
                        .font(Tokens.Font.subheadline)
                        .foregroundStyle(Tokens.Colour.ink3)
                }
                Text(plan.name).foregroundStyle(Tokens.Colour.ink2)
            }
            .padding(Tokens.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.Colour.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.bib))
            .padding(Tokens.Space.m)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Tokens.Colour.bg)
            .navigationTitle(title)
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
