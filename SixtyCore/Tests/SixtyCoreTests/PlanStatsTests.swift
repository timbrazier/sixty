import XCTest
@testable import SixtyCore

final class PlanStatsTests: XCTestCase {
    let plan = PlanCalendar(startDay: DayKey(rawValue: "2026-09-30")!, length: 60)
    let run = UUID()

    func progress(_ done: Bool) -> DayProgress {
        DayProgress(plannedActivityIDs: [run, UUID()], completedActivityIDs: done ? [run] : [],
                    requiredQuestionIDs: [], answeredQuestionIDs: [])
    }

    func complete() -> DayProgress {
        DayProgress(plannedActivityIDs: [run], completedActivityIDs: [run],
                    requiredQuestionIDs: [], answeredQuestionIDs: [])
    }

    func testDay14WithAPartialTodayAndOneMissedDay() {
        let today = plan.day(number: 14)
        var byDay: [DayKey: DayProgress] = [:]
        for number in 1...13 where number != 6 {
            byDay[plan.day(number: number)] = number == 9 ? progress(true) : complete()
        }
        byDay[today] = progress(true)

        let stats = PlanStats(calendar: plan, today: today, progress: byDay)
        XCTAssertEqual(stats.completeDays, 11)
        XCTAssertEqual(stats.partialDays, 1)
        XCTAssertEqual(stats.missedDays, 1)
        XCTAssertEqual(stats.countedDays, 13)      // today isn't counted until complete
        XCTAssertEqual(stats.completionPercent, 85) // 11 / 13
        XCTAssertEqual(stats.currentStreak, 4)      // days 10–13
        XCTAssertEqual(stats.bestStreak, 5)         // days 1–5
        XCTAssertEqual(stats.daysToGo, 46)
    }

    func testCompletingTodayCountsItAndExtendsTheStreak() {
        let today = plan.day(number: 3)
        let byDay = [plan.day(number: 1): complete(), plan.day(number: 2): complete(), today: complete()]
        let stats = PlanStats(calendar: plan, today: today, progress: byDay)
        XCTAssertEqual(stats.completionPercent, 100)
        XCTAssertEqual(stats.currentStreak, 3)
    }

    func testBeforeTheStart() {
        let stats = PlanStats(calendar: plan, today: plan.startDay.adding(days: -2), progress: [:])
        XCTAssertNil(stats.completionPercent)
        XCTAssertEqual(stats.currentStreak, 0)
        XCTAssertEqual(stats.daysToGo, 60)
    }

    func testAfterTheEndTheStreakEndsOnTheLastDay() {
        var byDay: [DayKey: DayProgress] = [:]
        for day in plan.days { byDay[day] = complete() }
        let stats = PlanStats(calendar: plan, today: plan.endDay.adding(days: 5), progress: byDay)
        XCTAssertEqual(stats.completeDays, 60)
        XCTAssertEqual(stats.currentStreak, 60)
        XCTAssertEqual(stats.daysToGo, 0)
    }
}
