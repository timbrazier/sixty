import Foundation

/// Reminder wording, from the design's notification notes.
public enum NotificationCopy {
    public struct Message: Equatable, Sendable {
        public let title: String
        public let body: String
    }

    /// "Day 10 of 60" / "Back from your run? Five ticks and a photo, about two minutes."
    /// The photo is only mentioned on photo days. On the last day:
    /// "Day 60 of 60" / "Last one. Log it, then see all 60 days."
    public static func morning(dayNumber: Int, length: Int, activityCount: Int, leadActivity: String?,
                               isPhotoDay: Bool) -> Message {
        if dayNumber == length {
            return Message(title: "Day \(dayNumber) of \(length)",
                           body: "Last one. Log it, then see all \(length) days.")
        }
        let opener = leadActivity.map { "Back from your \($0.lowercased())? " } ?? ""
        let ticks = activityCount == 1 ? "One tick" : "\(spelled(activityCount).capitalizedFirst) ticks"
        return Message(title: "Day \(dayNumber) of \(length)",
                       body: opener + "\(ticks)\(isPhotoDay ? " and a photo" : ""), about two minutes.")
    }

    /// "Day 14 · 3 of 5 done" / "Mobility and Read are still open. Tap to finish today's log."
    public static func eveningPartial(dayNumber: Int, done: Int, total: Int, openTitles: [String]) -> Message {
        let open: String
        if openTitles.isEmpty {
            open = "Today's questions are still open."
        } else {
            open = "\(joined(openTitles)) \(openTitles.count == 1 ? "is" : "are") still open."
        }
        return Message(title: "Day \(dayNumber) · \(done) of \(total) done",
                       body: open + " Tap to finish today's log.")
    }

    /// "Day 14 is still open" / "Log it before midnight and it counts."
    public static func eveningNothingLogged(dayNumber: Int) -> Message {
        Message(title: "Day \(dayNumber) is still open",
                body: "Log it before midnight and it counts.")
    }

    /// "Autumn reset starts tomorrow" / "First nudge at 06:45."
    public static func eveOfDayOne(planName: String, firstNudge: String?) -> Message {
        Message(title: "\(planName) starts tomorrow",
                body: firstNudge.map { "First nudge at \($0)." } ?? "Day 1 is tomorrow.")
    }

    /// "Photo day" / "Take your Day 10 photo while the light's good."
    public static func photoDay(dayNumber: Int) -> Message {
        Message(title: "Photo day",
                body: "Take your Day \(dayNumber) photo while the light's good.")
    }

    /// "A", "A and B", "A, B and C".
    public static func joined(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        default: return items.dropLast().joined(separator: ", ") + " and " + items.last!
        }
    }

    static func spelled(_ number: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        return words.indices.contains(number) ? words[number] : String(number)
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
