import SwiftUI
import SixtyCore

/// The Today tab: a countdown before the plan starts, otherwise the log for
/// the selected day (today by default, the last day once the plan is over).
struct TodayScreen: View {
    let plan: Plan
    @Environment(\.today) private var today
    @Environment(AppRouter.self) private var router
    @State private var selectedDay: DayKey?
    @State private var isStripOpen = false

    var body: some View {
        NavigationStack {
            Group {
                if case .notStarted(let daysToGo) = plan.calendar.phase(on: today) {
                    PlanCountdownView(plan: plan, daysToGo: daysToGo)
                } else {
                    DayView(plan: plan, day: shownDay, isStripOpen: $isStripOpen, onSelect: select)
                        .id(shownDay)
                        .transition(.opacity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(Tokens.Colour.bg)
        }
        .onChange(of: today) { _, _ in
            // A new day: go to it rather than staying on yesterday.
            selectedDay = nil
        }
        .onChange(of: router.requestedDay) { _, _ in takeRequest() }
        .onAppear(perform: takeRequest)
    }

    /// Today, or the last day once the plan has finished.
    private var currentDay: DayKey { min(today, plan.calendar.endDay) }

    private var shownDay: DayKey { selectedDay ?? currentDay }

    private func select(_ day: DayKey) {
        guard plan.calendar.contains(day) else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            selectedDay = day == currentDay ? nil : day
        }
    }

    /// A day opened from Progress, or (step 7) from a notification.
    private func takeRequest() {
        guard let day = router.requestedDay else { return }
        router.requestedDay = nil
        select(day)
    }
}

#Preview("Day 14, partial") {
    PreviewHost { plan in TodayScreen(plan: plan) }
}

#Preview("Before the plan starts") {
    PreviewHost(today: PreviewData.startDay.adding(days: -3)) { plan in TodayScreen(plan: plan) }
}
