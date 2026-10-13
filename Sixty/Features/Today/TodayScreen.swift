import SwiftUI
import SixtyCore

/// The Today tab: a countdown before the plan starts, otherwise the log for
/// the selected day (today by default, the last day once the plan is over).
struct TodayScreen: View {
    let plan: Plan
    @Environment(\.today) private var today
    @State private var selectedDay: DayKey?

    var body: some View {
        NavigationStack {
            Group {
                if case .notStarted(let daysToGo) = plan.calendar.phase(on: today) {
                    PlanCountdownView(plan: plan, daysToGo: daysToGo)
                } else {
                    DayView(plan: plan, day: shownDay,
                            onPrevious: shownDay > plan.calendar.startDay ? { move(by: -1) } : nil,
                            onNext: shownDay < currentDay ? { move(by: 1) } : nil)
                        .id(shownDay)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(Tokens.Colour.bg)
        }
        .onChange(of: today) { _, _ in
            // A new day: go to it rather than staying on yesterday.
            selectedDay = nil
        }
    }

    /// Today, or the last day once the plan has finished.
    private var currentDay: DayKey { min(today, plan.calendar.endDay) }

    private var shownDay: DayKey { selectedDay ?? currentDay }

    private func move(by days: Int) {
        let target = shownDay.adding(days: days)
        selectedDay = target == currentDay ? nil : target
    }
}

#Preview("Day 14, partial") {
    PreviewHost { plan in TodayScreen(plan: plan) }
}

#Preview("Before the plan starts") {
    PreviewHost(today: PreviewData.startDay.adding(days: -3)) { plan in TodayScreen(plan: plan) }
}
