import Foundation
import Observation
import SwiftData
import SixtyCore

/// The plan being set up, held in memory until "Start plan" saves it.
@Observable
final class PlanDraft {
    struct ActivityDraft: Identifiable, Equatable {
        var id = UUID()
        var title: String
        var target: String = ""
    }

    struct QuestionDraft: Identifiable, Equatable {
        var id = UUID()
        var prompt: String
        var kind: Question.Kind = .number
        var unit: String = ""
        var step: Double = 0.5
        var isOptional = false

        /// Matches `Question.summary`: "Number · hours", "Scale · 1–5".
        var summary: String {
            var parts: [String]
            switch kind {
            case .number: parts = ["Number"] + (unit.isEmpty ? [] : [unit])
            case .scale: parts = ["Scale", "1–5"]
            case .text: parts = ["Text"]
            }
            if isOptional { parts.append("optional") }
            return parts.joined(separator: " · ")
        }
    }

    enum Length: Hashable {
        case days30, days60, days90, custom

        var presetDays: Int? {
            switch self {
            case .days30: 30
            case .days60: 60
            case .days90: 90
            case .custom: nil
            }
        }
    }

    static let questionLimit = 2...4

    var name = ""
    var startDay: DayKey
    var length: Length = .days60
    var customDays = 45
    var activities: [ActivityDraft]
    var questions: [QuestionDraft]
    var morningOn = true
    var morningMinutes = 6 * 60 + 45
    var eveningOn = true
    var eveningMinutes = 21 * 60

    /// Starts tomorrow, pre-filled with the design's sample activities and
    /// questions so there's something to edit rather than a blank list.
    init(today: DayKey = .today()) {
        startDay = today.adding(days: 1)
        activities = [
            .init(title: "Morning run", target: "5 km"),
            .init(title: "Mobility", target: "10 min"),
            .init(title: "Push-ups", target: "3 × 20"),
            .init(title: "Water", target: "2 L"),
            .init(title: "Read", target: "20 pages"),
        ]
        questions = [
            .init(prompt: "Sleep", kind: .number, unit: "hours", step: 0.5),
            .init(prompt: "Energy", kind: .scale),
            .init(prompt: "Weight", kind: .number, unit: "kg", step: 0.1, isOptional: true),
        ]
    }

    var lengthDays: Int { length.presetDays ?? customDays }

    var endDay: DayKey { startDay.adding(days: lengthDays - 1) }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canContinueFromBasics: Bool { !trimmedName.isEmpty && lengthDays >= 1 }
    var canContinueFromActivities: Bool { !activities.isEmpty }
    var canStart: Bool { PlanDraft.questionLimit.contains(questions.count) }
    var canAddQuestion: Bool { questions.count < PlanDraft.questionLimit.upperBound }

    /// Inserts the plan with its activities and questions, and returns it.
    @discardableResult
    func save(in context: ModelContext) throws -> Plan {
        let plan = Plan(name: trimmedName,
                        startDay: startDay,
                        lengthDays: lengthDays,
                        morningReminderMinutes: morningOn ? morningMinutes : nil,
                        eveningReminderMinutes: eveningOn ? eveningMinutes : nil)
        context.insert(plan)
        plan.activities = activities.enumerated().map { index, draft in
            let target = draft.target.trimmingCharacters(in: .whitespacesAndNewlines)
            return Activity(id: draft.id,
                            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                            target: target.isEmpty ? nil : target,
                            sortOrder: index)
        }
        plan.questions = questions.enumerated().map { index, draft in
            let unit = draft.unit.trimmingCharacters(in: .whitespacesAndNewlines)
            return Question(id: draft.id,
                            prompt: draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                            kind: draft.kind,
                            unit: unit.isEmpty ? nil : unit,
                            step: draft.step,
                            isOptional: draft.isOptional,
                            sortOrder: index)
        }
        try context.save()
        return plan
    }
}
