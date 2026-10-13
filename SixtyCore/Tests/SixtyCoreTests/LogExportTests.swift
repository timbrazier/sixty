import XCTest
@testable import SixtyCore

final class LogExportTests: XCTestCase {
    let run = UUID(), read = UUID(), stretch = UUID(), sleep = UUID()

    func testOneRowPerDayIncludingEmptyDaysAndArchivedActivities() {
        let plan = PlanCalendar(startDay: DayKey(rawValue: "2026-09-30")!, length: 60)
        // Day 1 planned run + read; Day 3 planned run + stretch (read archived, stretch added).
        let day1 = LogExport.Day(day: plan.day(number: 1), dayNumber: 1,
                                 progress: DayProgress(plannedActivityIDs: [run, read], completedActivityIDs: [run, read],
                                                       requiredQuestionIDs: [sleep], answeredQuestionIDs: [sleep]),
                                 answers: [sleep: "7.5"], note: "Legs heavy, then fine", photoFilename: "a.jpg")
        let day2 = LogExport.Day(day: plan.day(number: 2), dayNumber: 2, progress: nil)
        let day3 = LogExport.Day(day: plan.day(number: 3), dayNumber: 3,
                                 progress: DayProgress(plannedActivityIDs: [run, stretch], completedActivityIDs: [run],
                                                       requiredQuestionIDs: [sleep], answeredQuestionIDs: []))

        let csv = LogExport.csv(days: [day1, day2, day3],
                                activities: [.init(id: run, title: "Morning run"),
                                             .init(id: read, title: "Read"),
                                             .init(id: stretch, title: "Stretch")],
                                questions: [.init(id: sleep, title: "Sleep")])
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }

        XCTAssertEqual(lines.count, 4) // header + one per day
        XCTAssertEqual(lines[0], "date,day,complete,activities done,Morning run,Read,Stretch,Sleep,note,photo")
        XCTAssertEqual(lines[1], "2026-09-30,1,yes,2 of 2,1,1,,7.5,\"Legs heavy, then fine\",a.jpg")
        XCTAssertEqual(lines[2], "2026-10-01,2,no,,,,,,,")
        XCTAssertEqual(lines[3], "2026-10-02,3,no,1 of 2,1,,0,,,")
    }
}
