import Foundation
import SwiftData
import SixtyCore

@Model
final class Plan {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Day 1 as a local calendar day ("yyyy-MM-dd"), so it never shifts with
    /// clock changes or time zones.
    var startDayKey: String
    var lengthDays: Int

    @Relationship(deleteRule: .cascade, inverse: \Activity.plan)
    var activities: [Activity] = []

    @Relationship(deleteRule: .cascade, inverse: \Question.plan)
    var questions: [Question] = []

    /// Reminder times as minutes after midnight; nil means off.
    var morningReminderMinutes: Int?
    var eveningReminderMinutes: Int?
    /// Weekly photo reminder: weekday 1 = Sunday … 7 = Saturday.
    var weeklyPhotoWeekday: Int?
    var weeklyPhotoMinutes: Int?

    var createdAt: Date

    init(id: UUID = UUID(),
         name: String,
         startDay: DayKey,
         lengthDays: Int = 60,
         morningReminderMinutes: Int? = 6 * 60 + 45,
         eveningReminderMinutes: Int? = 21 * 60,
         weeklyPhotoWeekday: Int? = nil,
         weeklyPhotoMinutes: Int? = nil) {
        self.id = id
        self.name = name
        self.startDayKey = startDay.rawValue
        self.lengthDays = lengthDays
        self.morningReminderMinutes = morningReminderMinutes
        self.eveningReminderMinutes = eveningReminderMinutes
        self.weeklyPhotoWeekday = weeklyPhotoWeekday
        self.weeklyPhotoMinutes = weeklyPhotoMinutes
        self.createdAt = Date()
    }

    var startDay: DayKey {
        get { DayKey(rawValue: startDayKey)! }
        set { startDayKey = newValue.rawValue }
    }

    var calendar: PlanCalendar {
        PlanCalendar(startDay: startDay, length: lengthDays)
    }

    /// Activities still in the plan, in display order.
    var activeActivities: [Activity] {
        activities.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Questions still in the plan, in display order.
    var activeQuestions: [Question] {
        questions.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func activity(id: UUID) -> Activity? { activities.first { $0.id == id } }
    func question(id: UUID) -> Question? { questions.first { $0.id == id } }
}
