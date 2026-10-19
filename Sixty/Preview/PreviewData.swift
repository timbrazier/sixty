import Foundation
import SwiftData
import SixtyCore

/// The design's sample plan: "Autumn reset", 30 Sep – 28 Nov 2026, three
/// non-negotiables, two bonus habits and an optional weight question, with
/// Days 1–13 logged and Day 14 under way.
@MainActor
enum PreviewData {
    static let startDay = DayKey(rawValue: "2026-09-30")!
    /// "Today" in previews: Tuesday 13 October, Day 14.
    static let today = DayKey(rawValue: "2026-10-13")!

    static var container: ModelContainer { container(loggedThrough: 13) }

    /// Sample data logged up to Day `loggedThrough`; at 60 the whole plan is
    /// done, for the final-day summary.
    static func container(loggedThrough: Int) -> ModelContainer {
        let container = emptyContainer
        populate(container.mainContext, loggedThrough: loggedThrough)
        return container
    }

    static var emptyContainer: ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Plan.self, Activity.self, Question.self, DayEntry.self,
                                   configurations: configuration)
    }

    /// Inserts the sample plan into `context`. Inserted before its activities
    /// and questions are attached, so everything shares one context.
    @discardableResult
    static func makePlan(in context: ModelContext) -> Plan {
        let plan = Plan(name: "Autumn reset", startDay: startDay,
                        morningReminderMinutes: 6 * 60 + 45,
                        eveningReminderMinutes: 21 * 60,
                        weeklyPhotoWeekday: 4, weeklyPhotoMinutes: 7 * 60)
        context.insert(plan)
        plan.activities = [
            Activity(title: "Morning run", target: "5 km", sortOrder: 0),
            Activity(title: "Push-ups", target: "3 × 20", sortOrder: 1),
            Activity(title: "Water", target: "2 L", sortOrder: 2),
            Activity(title: "Mobility", target: "10 min", sortOrder: 3, isBonus: true),
            Activity(title: "Read", target: "20 pages", sortOrder: 4, isBonus: true),
        ]
        plan.questions = [
            Question(prompt: "Weight", kind: .number, unit: "kg", step: 0.1, isOptional: true, sortOrder: 0),
        ]
        return plan
    }

    static func populate(_ context: ModelContext, loggedThrough: Int = 13) {
        let plan = makePlan(in: context)

        let core = plan.coreActivities.map(\.id)
        let bonus = plan.bonusActivities.map(\.id)
        let weight = plan.activeQuestions[0].id.uuidString

        // Mostly complete; Days 6 and 34 missed, every 9th day partial.
        // Bonus habits on most days, but not all.
        for number in 1...loggedThrough where number != 6 && number != 34 {
            let entry = DayEntry(day: plan.calendar.day(number: number), plan: plan)
            let coreDone = number % 9 == 0 ? Array(core.prefix(2)) : core
            entry.completedActivityIDs = coreDone + (number % 3 == 0 ? [] : bonus)
            entry.answers = number % 7 == 0 ? [weight: String(format: "%.1f", 82 - Double(number) * 0.1)] : [:]
            entry.journal = number == 13 ? "Legs heavy" : ""
            entry.photoFilename = number == 1 || number % 7 == 0 ? "preview-day-\(number).jpg" : nil
            context.insert(entry)
        }

        guard loggedThrough == 13 else { return }

        // Day 14 (today): 2 of 3 non-negotiables, one bonus habit.
        let today = DayEntry(day: plan.calendar.day(number: 14), plan: plan)
        today.completedActivityIDs = [core[0], core[2], bonus[0]]
        today.journal = "Legs heavy"
        context.insert(today)
    }
}
