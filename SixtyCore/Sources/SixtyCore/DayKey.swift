import Foundation

/// A local calendar day, stored as "yyyy-MM-dd".
///
/// Everything in the app is keyed by calendar day rather than by `Date`, so a
/// clock change, a late-night save or a change of time zone can never move an
/// entry onto a different day. Day arithmetic happens on the year/month/day
/// fields in a fixed UTC calendar, where every day is exactly 24 hours.
public struct DayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init?(year: Int, month: Int, day: Int) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard components.isValidDate(in: DayKey.utc) else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// The calendar day `date` falls on in `timeZone` (the device's by default).
    /// Always Gregorian, whatever calendar the device is set to.
    public init(_ date: Date, timeZone: TimeZone = .current) {
        let parts = DayKey.gregorian(timeZone).dateComponents([.year, .month, .day], from: date)
        self.year = parts.year!
        self.month = parts.month!
        self.day = parts.day!
    }

    /// Today in the device's time zone.
    public static func today(now: Date = Date(), timeZone: TimeZone = .current) -> DayKey {
        DayKey(now, timeZone: timeZone)
    }

    public init?(rawValue: String) {
        let parts = rawValue.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    public var rawValue: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public var description: String { rawValue }

    /// Midnight at the start of this day in `timeZone`.
    public func startDate(timeZone: TimeZone = .current) -> Date {
        let calendar = DayKey.gregorian(timeZone)
        let noon = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        return calendar.startOfDay(for: noon)
    }

    /// A time of day on this day in `timeZone`, e.g. 06:45 for a reminder.
    /// On a clock-change day a time that doesn't exist moves forward.
    public func date(minutesAfterMidnight minutes: Int, timeZone: TimeZone = .current) -> Date {
        let components = DateComponents(year: year, month: month, day: day,
                                        hour: minutes / 60, minute: minutes % 60)
        return DayKey.gregorian(timeZone).date(from: components)!
    }

    public func adding(days: Int) -> DayKey {
        let shifted = DayKey.utc.date(byAdding: .day, value: days, to: utcDate)!
        return DayKey(shifted, timeZone: DayKey.utc.timeZone)
    }

    /// Whole calendar days from `self` to `other`; negative if `other` is earlier.
    public func days(to other: DayKey) -> Int {
        DayKey.utc.dateComponents([.day], from: utcDate, to: other.utcDate).day!
    }

    /// 1 = Sunday … 7 = Saturday, matching `Calendar.component(.weekday, ...)`.
    public var weekday: Int {
        DayKey.utc.component(.weekday, from: utcDate)
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    // MARK: Codable as the raw string

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let key = DayKey(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a day key: \(raw)")
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    // MARK: Private

    private var utcDate: Date {
        DayKey.utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    static let utc = gregorian(TimeZone(identifier: "UTC")!)

    static func gregorian(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
