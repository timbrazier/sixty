import XCTest
@testable import SixtyCore

final class ReminderPlannerTests: XCTestCase {
    let london = TimeZone(identifier: "Europe/London")!
    let plan = PlanCalendar(startDay: DayKey(rawValue: "2026-09-30")!, length: 60)
    let settings = ReminderPlanner.Settings(morningMinutes: 6 * 60 + 45, eveningMinutes: 21 * 60)
    let run = UUID(), read = UUID()

    func at(_ day: DayKey, _ hour: Int, _ minute: Int = 0) -> Date {
        day.date(minutesAfterMidnight: hour * 60 + minute, timeZone: london)
    }

    func state(done: Set<UUID>) -> ReminderPlanner.TodayState {
        let progress = DayProgress(plannedActivityIDs: [run, read], completedActivityIDs: done,
                                   requiredQuestionIDs: [], answeredQuestionIDs: [])
        return .init(progress: progress, openTitles: [run, read].filter { !done.contains($0) }.map { $0 == run ? "Morning run" : "Read" })
    }

    func reminders(today: DayKey, now: Date, state: ReminderPlanner.TodayState? = nil,
                   settings: ReminderPlanner.Settings? = nil) -> [PlannedReminder] {
        ReminderPlanner.plan(calendar: plan, planName: "Autumn reset", settings: settings ?? self.settings,
                             activityCount: 2, leadActivity: "run", today: today, todayState: state,
                             now: now, timeZone: london)
    }

    func testFourteenDaysOfMorningsAndEveningsStayUnderTheLimit() {
        let today = plan.day(number: 14)
        let weekly = ReminderPlanner.Settings(morningMinutes: 405, eveningMinutes: 1260,
                                              weeklyPhotoWeekday: 1, weeklyPhotoMinutes: 600)
        let all = reminders(today: today, now: at(today, 5), settings: weekly)
        XCTAssertEqual(all.filter { $0.kind == .morning }.count, 14)
        XCTAssertEqual(all.filter { $0.kind == .evening }.count, 14)
        XCTAssertEqual(all.filter { $0.kind == .photo }.count, 2)
        XCTAssertLessThanOrEqual(all.count, 64)
        XCTAssertEqual(Set(all.map(\.identifier)).count, all.count)
    }

    func testCompletedDayHasNoEveningCheckIn() {
        let today = plan.day(number: 14)
        let all = reminders(today: today, now: at(today, 12), state: state(done: [run, read]))
        XCTAssertNil(all.first { $0.kind == .evening && $0.day == today })
        // Tomorrow's is still there.
        XCTAssertNotNil(all.first { $0.kind == .evening && $0.day == today.adding(days: 1) })
    }

    func testPartialDayEveningNamesWhatsLeft() {
        let today = plan.day(number: 14)
        let evening = reminders(today: today, now: at(today, 12), state: state(done: [run]))
            .first { $0.identifier == "evening-2026-10-13" }
        XCTAssertEqual(evening?.message.title, "Day 14 · 1 of 2 done")
        XCTAssertEqual(evening?.message.body, "Read is still open. Tap to finish today's log.")
    }

    func testNothingLoggedEvening() {
        let today = plan.day(number: 14)
        let evening = reminders(today: today, now: at(today, 12), state: state(done: []))
            .first { $0.identifier == "evening-2026-10-13" }
        XCTAssertEqual(evening?.message.title, "Day 14 is still open")
    }

    func testRemindersInThePastAreDropped() {
        let today = plan.day(number: 14)
        let all = reminders(today: today, now: at(today, 7))
        XCTAssertNil(all.first { $0.kind == .morning && $0.day == today })
        XCTAssertNotNil(all.first { $0.kind == .evening && $0.day == today })
    }

    func testStopsAtTheLastDay() {
        let today = plan.day(number: 55)
        let all = reminders(today: today, now: at(today, 5))
        XCTAssertEqual(all.filter { $0.kind == .morning }.count, 6)
        XCTAssertEqual(all.last { $0.kind == .morning }?.message.body, "Last one. Log it, then see all 60 days.")
    }

    func testEveOfDayOne() {
        let today = plan.startDay.adding(days: -3)
        let all = reminders(today: today, now: at(today, 12))
        let eve = all.first { $0.kind == .eve }
        XCTAssertEqual(eve?.day, plan.startDay.adding(days: -1))
        XCTAssertEqual(eve?.message, .init(title: "Autumn reset starts tomorrow", body: "First nudge at 06:45."))
        XCTAssertEqual(all.first { $0.kind == .morning }?.day, plan.startDay)
    }

    func testFireTimesHoldOnClockChangeDays() {
        // 25 October 2026: clocks go back.
        let longPlan = PlanCalendar(startDay: DayKey(rawValue: "2026-10-20")!, length: 30)
        let today = DayKey(rawValue: "2026-10-24")!
        let all = ReminderPlanner.plan(calendar: longPlan, planName: "x", settings: settings,
                                       activityCount: 1, leadActivity: nil, today: today, todayState: nil,
                                       now: at(today, 5), timeZone: london)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = london
        for reminder in all where reminder.day == DayKey(rawValue: "2026-10-25")! {
            let parts = calendar.dateComponents([.day, .hour, .minute], from: reminder.fireDate(timeZone: london))
            XCTAssertEqual(parts.day, 25)
            XCTAssertEqual(parts.hour, reminder.kind == .morning ? 6 : 21)
        }
    }

    func testLeadActivity() {
        XCTAssertEqual(ReminderPlanner.leadActivity(fromFirstActivityTitle: "Morning run"), "run")
        XCTAssertNil(ReminderPlanner.leadActivity(fromFirstActivityTitle: "Mobility"))
    }
}
