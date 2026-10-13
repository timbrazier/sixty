import SwiftUI
import SwiftData
import SixtyCore

/// Plan setup until a plan exists, then the four tabs.
struct RootView: View {
    @Query(sort: \Plan.createdAt, order: .reverse) private var plans: [Plan]
    @Environment(\.scenePhase) private var scenePhase
    @State private var today: DayKey

    init(today: DayKey = .today()) {
        _today = State(initialValue: today)
    }

    var body: some View {
        Group {
            if let plan = plans.first {
                MainTabView(plan: plan)
            } else {
                SetupPlaceholderView()
            }
        }
        .environment(\.today, today)
        .tint(Tokens.Colour.accent)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { today = .today() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            today = .today()
        }
    }
}

struct MainTabView: View {
    let plan: Plan

    var body: some View {
        TabView {
            PlaceholderScreen(title: "Today", plan: plan)
                .tabItem { Label("Today", systemImage: "circle.circle") }
            PlaceholderScreen(title: "Progress", plan: plan)
                .tabItem { Label("Progress", systemImage: "square.grid.3x3") }
            PlaceholderScreen(title: "Photos", plan: plan)
                .tabItem { Label("Photos", systemImage: "photo.on.rectangle") }
            PlaceholderScreen(title: "Settings", plan: plan)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

// MARK: Placeholders until steps 2–8 replace them

private struct SetupPlaceholderView: View {
    var body: some View {
        ContentUnavailableView("New plan", systemImage: "flag",
                               description: Text("Plan setup arrives in step 2."))
            .background(Tokens.Colour.bg)
    }
}

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
    RootView(today: PreviewData.today)
        .modelContainer(PreviewData.container)
}

#Preview("No plan") {
    RootView()
        .modelContainer(PreviewData.emptyContainer)
}
