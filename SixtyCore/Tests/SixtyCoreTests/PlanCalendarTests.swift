import XCTest
@testable import SixtyCore

final class PlanCalendarTests: XCTestCase {
    let london = TimeZone(identifier: "Europe/London")!

    func key(_ raw: String) -> DayKey { DayKey(rawValue: raw)! }

    /// An instant given as London wall-clock time.
    func londonTime(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = london
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // MARK: DayKey

    func testRoundTripsRawValue() {
        XCTAssertEqual(key("2026-09-30").rawValue, "2026-09-30")
        XCTAssertNil(DayKey(rawValue: "2026-02-30"))
        XCTAssertNil(DayKey(rawValue: "nonsense"))
    }

    func testMonthAndYearEnds() {
        XCTAssertEqual(key("2026-10-31").adding(days: 1), key("2026-11-01"))
        XCTAssertEqual(key("2026-12-31").adding(days: 1), key("2027-01-01"))
        XCTAssertEqual(key("2027-02-28").adding(days: 1), key("2027-03-01"))
        XCTAssertEqual(key("2028-02-28").adding(days: 1), key("2028-02-29"))
        XCTAssertEqual(key("2028-03-01").adding(days: -1), key("2028-02-29"))
    }

    func testLateAndEarlyTimesLandOnTheirLocalDay() {
        // 23:30 BST is 22:30 UTC, still the same London day.
        XCTAssertEqual(DayKey(londonTime(2026, 10, 13, 23, 30), timeZone: london), key("2026-10-13"))
        // 00:30 BST is 23:30 UTC the previous day, but it's the new London day.
        XCTAssertEqual(DayKey(londonTime(2026, 10, 14, 0, 30), timeZone: london), key("2026-10-14"))
    }

    // MARK: Day numbers

    func testSamplePlan() {
        let plan = PlanCalendar(startDay: key("2026-09-30"), length: 60)
        XCTAssertEqual(plan.endDay, key("2026-11-28"))
        XCTAssertEqual(plan.dayNumber(for: key("2026-09-30")), 1)
        XCTAssertEqual(plan.dayNumber(for: key("2026-10-13")), 14)
        XCTAssertEqual(plan.dayNumber(for: key("2026-11-28")), 60)
        XCTAssertEqual(plan.day(number: 14), key("2026-10-13"))
        XCTAssertEqual(plan.days.count, 60)
    }

    func testAcrossAutumnClockChange() {
        // Clocks go back at 02:00 on Sunday 25 October 2026: a 25-hour day.
        let plan = PlanCalendar(startDay: key("2026-10-24"), length: 60)
        XCTAssertEqual(plan.dayNumber(for: londonTime(2026, 10, 24, 23, 30), timeZone: london), 1)
        XCTAssertEqual(plan.dayNumber(for: londonTime(2026, 10, 25, 0, 30), timeZone: london), 2)
        XCTAssertEqual(plan.dayNumber(for: londonTime(2026, 10, 25, 23, 30), timeZone: london), 2)
        XCTAssertEqual(plan.dayNumber(for: londonTime(2026, 10, 26, 0, 30), timeZone: london), 3)
    }

    func testAcrossSpringClockChange() {
        // Clocks go forward at 01:00 on Sunday 29 March 2026: a 23-hour day.
        let plan = PlanCalendar(startDay: key("2026-03-28"), length: 60)
        XCTAssertEqual(plan.dayNumber(for: londonTime(2026, 3, 28, 23, 30), timeZone: london), 1)
        XCTAssertEqual(plan.dayNumber(for: londonTime(2026, 3, 29, 0, 30), timeZone: london), 2)
        XCTAssertEqual(plan.dayNumber(for: londonTime(2026, 3, 29, 23, 30), timeZone: london), 2)
        XCTAssertEqual(plan.dayNumber(for: londonTime(2026, 3, 30, 0, 30), timeZone: london), 3)
    }

    func testPlanSpanningBothClockChanges() {
        let plan = PlanCalendar(startDay: key("2026-03-01"), length: 300)
        XCTAssertEqual(plan.dayNumber(for: key("2026-12-25")), 300)
        XCTAssertEqual(plan.dayNumber(for: londonTime(2026, 12, 25, 23, 59), timeZone: london), 300)
    }

    func testRemindersOnClockChangeDays() {
        // 06:45 and 21:00 exist on both change days and land on that day.
        for raw in ["2026-03-29", "2026-10-25"] {
            for minutes in [6 * 60 + 45, 21 * 60] {
                let date = key(raw).date(minutesAfterMidnight: minutes, timeZone: london)
                XCTAssertEqual(DayKey(date, timeZone: london), key(raw))
            }
        }
    }

    func testPhases() {
        let plan = PlanCalendar(startDay: key("2026-09-30"), length: 60)
        XCTAssertEqual(plan.phase(on: key("2026-09-27")), .notStarted(daysToGo: 3))
        XCTAssertEqual(plan.phase(on: key("2026-09-29")), .notStarted(daysToGo: 1))
        XCTAssertEqual(plan.phase(on: key("2026-10-13")), .inProgress(dayNumber: 14))
        XCTAssertEqual(plan.phase(on: key("2026-11-29")), .finished)
        XCTAssertEqual(plan.daysSoFar(today: key("2026-10-13")).count, 14)
        XCTAssertEqual(plan.daysSoFar(today: key("2026-09-01")).count, 0)
        XCTAssertEqual(plan.daysSoFar(today: key("2027-01-01")).count, 60)
        XCTAssertEqual(plan.daysToGo(today: key("2026-10-13")), 46)
    }
}
