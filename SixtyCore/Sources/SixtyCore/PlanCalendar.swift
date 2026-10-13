import Foundation

/// The days of a plan: Day 1 is the start day, Day `length` is the last.
public struct PlanCalendar: Equatable, Sendable {
    public let startDay: DayKey
    public let length: Int

    public init(startDay: DayKey, length: Int) {
        precondition(length > 0, "A plan needs at least one day")
        self.startDay = startDay
        self.length = length
    }

    public var endDay: DayKey { startDay.adding(days: length - 1) }

    public var days: [DayKey] { (0..<length).map { startDay.adding(days: $0) } }

    /// 1-based day number. Below 1 before the plan starts, above `length` after it ends.
    public func dayNumber(for day: DayKey) -> Int {
        startDay.days(to: day) + 1
    }

    /// The day number for an instant, using the calendar day it falls on locally.
    public func dayNumber(for date: Date, timeZone: TimeZone = .current) -> Int {
        dayNumber(for: DayKey(date, timeZone: timeZone))
    }

    public func day(number: Int) -> DayKey {
        startDay.adding(days: number - 1)
    }

    public func contains(_ day: DayKey) -> Bool {
        (1...length).contains(dayNumber(for: day))
    }

    public enum Phase: Equatable, Sendable {
        /// The plan hasn't started; `daysToGo` is 1 on the eve of Day 1.
        case notStarted(daysToGo: Int)
        case inProgress(dayNumber: Int)
        case finished
    }

    public func phase(on day: DayKey) -> Phase {
        let number = dayNumber(for: day)
        if number < 1 { return .notStarted(daysToGo: 1 - number) }
        if number > length { return .finished }
        return .inProgress(dayNumber: number)
    }

    /// Days of the plan that are over or under way as of `today`, oldest first.
    public func daysSoFar(today: DayKey) -> [DayKey] {
        let count = min(max(dayNumber(for: today), 0), length)
        return (0..<count).map { startDay.adding(days: $0) }
    }

    /// Days left after `today`, not counting today.
    public func daysToGo(today: DayKey) -> Int {
        min(max(length - dayNumber(for: today), 0), length)
    }
}
