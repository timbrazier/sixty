import Foundation

/// One local notification to schedule.
public struct PlannedReminder: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case morning, evening, photo
        /// The evening before Day 1.
        case eve
    }

    public let kind: Kind
    public let day: DayKey
    public let minutesAfterMidnight: Int
    public let message: NotificationCopy.Message

    /// "evening-2026-10-13": stable, so today's evening reminder can be
    /// removed by name once the day is complete.
    public var identifier: String { Self.identifier(kind, day) }

    public static func identifier(_ kind: Kind, _ day: DayKey) -> String {
        "\(kind.rawValue)-\(day.rawValue)"
    }

    public func fireDate(timeZone: TimeZone = .current) -> Date {
        day.date(minutesAfterMidnight: minutesAfterMidnight, timeZone: timeZone)
    }
}

/// Works out the next two weeks of reminders. iOS keeps at most 64 pending
/// local notifications, so the app schedules a rolling window and redoes it
/// on every open and every save.
public enum ReminderPlanner {
    public static let windowDays = 14

    public struct Settings: Equatable, Sendable {
        public var morningMinutes: Int?
        public var eveningMinutes: Int?
        /// 1 = Sunday … 7 = Saturday.
        public var weeklyPhotoWeekday: Int?
        public var weeklyPhotoMinutes: Int?

        public init(morningMinutes: Int?, eveningMinutes: Int?,
                    weeklyPhotoWeekday: Int? = nil, weeklyPhotoMinutes: Int? = nil) {
            self.morningMinutes = morningMinutes
            self.eveningMinutes = eveningMinutes
            self.weeklyPhotoWeekday = weeklyPhotoWeekday
            self.weeklyPhotoMinutes = weeklyPhotoMinutes
        }
    }

    /// Where today stands, for the wording of tonight's check-in.
    public struct TodayState: Equatable, Sendable {
        public var progress: DayProgress
        /// Titles of the activities not yet ticked, in order.
        public var openTitles: [String]

        public init(progress: DayProgress, openTitles: [String]) {
            self.progress = progress
            self.openTitles = openTitles
        }
    }

    public static func plan(calendar: PlanCalendar,
                            planName: String,
                            settings: Settings,
                            activityCount: Int,
                            leadActivity: String?,
                            today: DayKey,
                            todayState: TodayState?,
                            now: Date,
                            timeZone: TimeZone = .current) -> [PlannedReminder] {
        var reminders: [PlannedReminder] = []

        for offset in 0..<windowDays {
            let day = today.adding(days: offset)
            let number = calendar.dayNumber(for: day)

            // The evening before Day 1.
            if number == 0 {
                let minutes = settings.eveningMinutes ?? 20 * 60
                let firstNudge = settings.morningMinutes.map(clockTime)
                reminders.append(.init(kind: .eve, day: day, minutesAfterMidnight: minutes,
                                       message: NotificationCopy.eveOfDayOne(planName: planName, firstNudge: firstNudge)))
                continue
            }
            guard calendar.contains(day) else { continue }

            if let minutes = settings.morningMinutes {
                reminders.append(.init(kind: .morning, day: day, minutesAfterMidnight: minutes,
                                       message: NotificationCopy.morning(dayNumber: number, length: calendar.length,
                                                                         activityCount: activityCount,
                                                                         leadActivity: leadActivity)))
            }

            if let minutes = settings.eveningMinutes {
                if day == today, let state = todayState {
                    // Never nag about a day that's already done.
                    if !state.progress.isComplete {
                        let message = state.progress.hasAnyProgress
                            ? NotificationCopy.eveningPartial(dayNumber: number, done: state.progress.activitiesDone,
                                                              total: state.progress.activitiesTotal,
                                                              openTitles: state.openTitles)
                            : NotificationCopy.eveningNothingLogged(dayNumber: number)
                        reminders.append(.init(kind: .evening, day: day, minutesAfterMidnight: minutes, message: message))
                    }
                } else {
                    reminders.append(.init(kind: .evening, day: day, minutesAfterMidnight: minutes,
                                           message: NotificationCopy.eveningNothingLogged(dayNumber: number)))
                }
            }

            if let weekday = settings.weeklyPhotoWeekday, let minutes = settings.weeklyPhotoMinutes,
               day.weekday == weekday {
                reminders.append(.init(kind: .photo, day: day, minutesAfterMidnight: minutes,
                                       message: NotificationCopy.weeklyPhoto(dayNumber: number)))
            }
        }

        return reminders.filter { $0.fireDate(timeZone: timeZone) > now }
    }

    /// "06:45"
    static func clockTime(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// "Back from your run?" only reads well for a few kinds of activity.
    public static func leadActivity(fromFirstActivityTitle title: String?) -> String? {
        guard let word = title?.split(separator: " ").last?.lowercased() else { return nil }
        let outings: Set = ["run", "walk", "ride", "swim", "workout", "session", "class", "gym", "hike", "cycle"]
        return outings.contains(word) ? word : nil
    }
}
