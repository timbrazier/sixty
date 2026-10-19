import XCTest
@testable import SixtyCore

final class ProgressTests: XCTestCase {
    func key(_ raw: String) -> DayKey { DayKey(rawValue: raw)! }

    let run = UUID(), read = UUID(), sleep = UUID(), weight = UUID()

    func progress(done: Set<UUID>, answered: Set<UUID>) -> DayProgress {
        DayProgress(plannedActivityIDs: [run, read], completedActivityIDs: done,
                    requiredQuestionIDs: [sleep], answeredQuestionIDs: answered)
    }

    // MARK: Completion

    func testCompleteNeedsActivitiesAndRequiredQuestions() {
        XCTAssertTrue(progress(done: [run, read], answered: [sleep]).isComplete)
        XCTAssertFalse(progress(done: [run, read], answered: []).isComplete)
        XCTAssertFalse(progress(done: [run], answered: [sleep]).isComplete)
        // Optional questions (weight) aren't required.
        XCTAssertTrue(progress(done: [run, read], answered: [sleep]).isComplete)
    }

    func testBonusHabitsDontHoldADayBack() {
        let stretch = UUID()
        let p = DayProgress(plannedActivityIDs: [run, read], completedActivityIDs: [run, read],
                            requiredQuestionIDs: [sleep], answeredQuestionIDs: [sleep],
                            bonusActivityIDs: [stretch])
        XCTAssertTrue(p.isComplete)
        XCTAssertEqual(p.bonusDone, 0)
        XCTAssertEqual(p.bonusTotal, 1)
        XCTAssertEqual(p.activitiesTotal, 2)
    }

    func testOnlyABonusHabitTickedCountsAsPartial() {
        let stretch = UUID()
        let p = DayProgress(plannedActivityIDs: [run], completedActivityIDs: [stretch],
                            requiredQuestionIDs: [], answeredQuestionIDs: [],
                            bonusActivityIDs: [stretch])
        XCTAssertFalse(p.isComplete)
        XCTAssertEqual(DayStatus.of(day: key("2026-10-12"), today: key("2026-10-13"), progress: p),
                       .partial(done: 0, total: 1))
    }

    func testTicksForActivitiesOutsideTheSnapshotDontCount() {
        // An activity added to the plan later doesn't change an old day.
        let p = progress(done: [run, read, UUID()], answered: [sleep, weight])
        XCTAssertEqual(p.activitiesDone, 2)
        XCTAssertTrue(p.isComplete)
    }

    func testStatuses() {
        let today = key("2026-10-13")
        XCTAssertEqual(DayStatus.of(day: key("2026-10-14"), today: today, progress: nil), .upcoming)
        XCTAssertEqual(DayStatus.of(day: today, today: today, progress: nil), .open)
        XCTAssertEqual(DayStatus.of(day: key("2026-10-12"), today: today, progress: nil), .missed)
        XCTAssertEqual(DayStatus.of(day: key("2026-10-12"), today: today,
                                    progress: progress(done: [], answered: [])), .missed)
        XCTAssertEqual(DayStatus.of(day: today, today: today,
                                    progress: progress(done: [run], answered: [])), .partial(done: 1, total: 2))
        XCTAssertEqual(DayStatus.of(day: today, today: today,
                                    progress: progress(done: [run, read], answered: [sleep])), .complete)
    }

    // MARK: Streaks

    func testCurrentStreakSurvivesAnUnfinishedToday() {
        let days: Set = [key("2026-10-10"), key("2026-10-11"), key("2026-10-12")]
        XCTAssertEqual(Streak.current(completeDays: days, today: key("2026-10-13")), 3)
        XCTAssertEqual(Streak.current(completeDays: days.union([key("2026-10-13")]), today: key("2026-10-13")), 4)
        // Yesterday missed: the streak is broken.
        XCTAssertEqual(Streak.current(completeDays: days, today: key("2026-10-14")), 0)
    }

    func testStreakAcrossMonthEnd() {
        let days: Set = [key("2026-10-30"), key("2026-10-31"), key("2026-11-01")]
        XCTAssertEqual(Streak.current(completeDays: days, today: key("2026-11-01")), 3)
    }

    func testLongestStreak() {
        let days: Set = [key("2026-10-01"), key("2026-10-02"),
                         key("2026-10-05"), key("2026-10-06"), key("2026-10-07"),
                         key("2026-10-09")]
        XCTAssertEqual(Streak.longest(completeDays: days), 3)
        XCTAssertEqual(Streak.longest(completeDays: []), 0)
    }

    // MARK: CSV

    func testCSVQuoting() {
        let csv = CSVWriter.csv(header: ["date", "journal"],
                                rows: [["2026-10-13", "Legs heavy, slept badly"],
                                       ["2026-10-14", "Said \"never again\"\nthen did it"],
                                       ["2026-10-15", ""]])
        XCTAssertEqual(csv, "date,journal\r\n"
                       + "2026-10-13,\"Legs heavy, slept badly\"\r\n"
                       + "2026-10-14,\"Said \"\"never again\"\"\nthen did it\"\r\n"
                       + "2026-10-15,\r\n")
    }

    // MARK: Notification copy

    func testNotificationCopyMatchesDesign() {
        XCTAssertEqual(NotificationCopy.eveningPartial(dayNumber: 14, done: 3, total: 5,
                                                       openTitles: ["Mobility", "Read"]),
                       .init(title: "Day 14 · 3 of 5 done",
                             body: "Mobility and Read are still open. Tap to finish today's log."))
        XCTAssertEqual(NotificationCopy.eveningNothingLogged(dayNumber: 14),
                       .init(title: "Day 14 is still open", body: "Log it before midnight and it counts."))
        XCTAssertEqual(NotificationCopy.morning(dayNumber: 14, length: 60, activityCount: 5, leadActivity: "Run"),
                       .init(title: "Day 14 of 60",
                             body: "Back from your run? Five ticks and a photo, about two minutes."))
        XCTAssertEqual(NotificationCopy.morning(dayNumber: 60, length: 60, activityCount: 5, leadActivity: "Run"),
                       .init(title: "Day 60 of 60", body: "Last one. Log it, then see all 60 days."))
        XCTAssertEqual(NotificationCopy.eveOfDayOne(planName: "Autumn reset", firstNudge: "06:45"),
                       .init(title: "Autumn reset starts tomorrow", body: "First nudge at 06:45."))
        XCTAssertEqual(NotificationCopy.joined(["A", "B", "C"]), "A, B and C")
    }
}
