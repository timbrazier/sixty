import Foundation
import SwiftData
import SixtyCore

/// One day's log. Created the first time something is logged for that day.
@Model
final class DayEntry {
    @Attribute(.unique) var id: UUID
    /// The local calendar day, "yyyy-MM-dd". One entry per day.
    @Attribute(.unique) var dayKey: String
    /// Midnight at the start of the day, for sorting and display.
    var date: Date

    var completedActivityIDs: [UUID]
    /// Question id (uuidString) → answer text.
    var answers: [String: String]
    var journal: String
    /// File name in Documents/Photos, if a photo was taken.
    var photoFilename: String?

    /// What the plan asked for on this day, captured when the entry was made.
    /// Completion is judged against these, so editing the plan later never
    /// changes how a past day looks.
    var plannedActivityIDs: [UUID]
    var plannedQuestionIDs: [UUID]
    var requiredQuestionIDs: [UUID]

    /// When logging started and when the day first became complete, for
    /// "Logged in 1:48".
    var firstEditedAt: Date?
    var completedAt: Date?
    var updatedAt: Date

    init(day: DayKey, plan: Plan) {
        self.id = UUID()
        self.dayKey = day.rawValue
        self.date = day.startDate()
        self.completedActivityIDs = []
        self.answers = [:]
        self.journal = ""
        self.photoFilename = nil
        self.plannedActivityIDs = []
        self.plannedQuestionIDs = []
        self.requiredQuestionIDs = []
        self.firstEditedAt = nil
        self.completedAt = nil
        self.updatedAt = Date()
        snapshot(plan)
    }

    var day: DayKey { DayKey(rawValue: dayKey)! }

    /// Copies the plan's current activities and questions onto this day.
    /// Used when the entry is created, and for today when the plan is edited.
    func snapshot(_ plan: Plan) {
        plannedActivityIDs = plan.activeActivities.map(\.id)
        plannedQuestionIDs = plan.activeQuestions.map(\.id)
        requiredQuestionIDs = plan.activeQuestions.filter { !$0.isOptional }.map(\.id)
    }

    func answer(for questionID: UUID) -> String {
        answers[questionID.uuidString] ?? ""
    }

    var progress: DayProgress {
        let answered = answers.compactMap { key, value -> UUID? in
            value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : UUID(uuidString: key)
        }
        return DayProgress(plannedActivityIDs: plannedActivityIDs,
                           completedActivityIDs: Set(completedActivityIDs),
                           requiredQuestionIDs: requiredQuestionIDs,
                           answeredQuestionIDs: Set(answered))
    }

    var isComplete: Bool { progress.isComplete }
}
