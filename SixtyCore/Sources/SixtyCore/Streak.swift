import Foundation

public enum Streak {
    /// Complete days in a row ending today, or ending yesterday while today is
    /// still being logged: an unfinished today doesn't break the streak until
    /// it's over.
    public static func current(completeDays: Set<DayKey>, today: DayKey) -> Int {
        var day = completeDays.contains(today) ? today : today.adding(days: -1)
        var count = 0
        while completeDays.contains(day) {
            count += 1
            day = day.adding(days: -1)
        }
        return count
    }

    /// The longest run of consecutive complete days.
    public static func longest(completeDays: Set<DayKey>) -> Int {
        var best = 0
        for day in completeDays where !completeDays.contains(day.adding(days: -1)) {
            var length = 1
            while completeDays.contains(day.adding(days: length)) { length += 1 }
            best = max(best, length)
        }
        return best
    }
}
