import Foundation

/// The numbers on the Progress tab and the final-day summary.
public struct PlanStats: Equatable, Sendable {
    public let completeDays: Int
    public let partialDays: Int
    public let missedDays: Int
    /// Days that count towards completion: every day before today, plus
    /// today once it's complete (an unfinished today doesn't drag it down).
    public let countedDays: Int
    public let currentStreak: Int
    public let bestStreak: Int
    public let daysToGo: Int

    /// 0–100, or nil before there's anything to count.
    public var completionPercent: Int? {
        guard countedDays > 0 else { return nil }
        return Int((Double(completeDays) / Double(countedDays) * 100).rounded())
    }

    public init(calendar: PlanCalendar, today: DayKey, progress: [DayKey: DayProgress]) {
        var complete = 0, partial = 0, missed = 0, counted = 0
        var completeSet = Set<DayKey>()
        for day in calendar.daysSoFar(today: today) {
            switch DayStatus.of(day: day, today: today, progress: progress[day]) {
            case .complete:
                complete += 1
                counted += 1
                completeSet.insert(day)
            case .partial:
                if day < today {
                    partial += 1
                    counted += 1
                }
            case .missed:
                missed += 1
                counted += 1
            case .open, .upcoming:
                break
            }
        }
        completeDays = complete
        partialDays = partial
        missedDays = missed
        countedDays = counted
        currentStreak = Streak.current(completeDays: completeSet, today: min(today, calendar.endDay))
        bestStreak = Streak.longest(completeDays: completeSet)
        daysToGo = calendar.daysToGo(today: today)
    }
}
