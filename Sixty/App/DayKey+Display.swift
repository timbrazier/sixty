import Foundation
import SixtyCore

extension DayKey {
    /// "Tuesday 13 October"
    var longName: String {
        startDate().formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    /// "Sun 11 Oct"
    var shortName: String {
        startDate().formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// "Wed"
    var weekdayName: String {
        startDate().formatted(.dateTime.weekday(.abbreviated))
    }
}

/// "06:45" from minutes after midnight, in the device's time format.
func timeString(minutesAfterMidnight minutes: Int) -> String {
    DayKey.today().date(minutesAfterMidnight: minutes).formatted(date: .omitted, time: .shortened)
}
