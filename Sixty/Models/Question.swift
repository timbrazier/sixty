import Foundation
import SwiftData

/// A question asked every day. Answers are stored as text on the day entry,
/// keyed by the question's id. Archived rather than deleted.
@Model
final class Question {
    enum Kind: String, CaseIterable, Codable {
        /// A number with a stepper, e.g. Sleep in hours.
        case number
        /// 1–5 chips, e.g. Energy.
        case scale
        /// Free text.
        case text
    }

    @Attribute(.unique) var id: UUID
    var prompt: String
    var kindRaw: String
    /// Unit shown after a number: "hours", "kg".
    var unit: String?
    /// Stepper increment for number questions.
    var step: Double
    /// Optional questions (e.g. Weight) don't block a day from completing.
    var isOptional: Bool
    var sortOrder: Int
    var isArchived: Bool
    var plan: Plan?

    init(id: UUID = UUID(),
         prompt: String,
         kind: Kind = .text,
         unit: String? = nil,
         step: Double = 0.5,
         isOptional: Bool = false,
         sortOrder: Int,
         isArchived: Bool = false) {
        self.id = id
        self.prompt = prompt
        self.kindRaw = kind.rawValue
        self.unit = unit
        self.step = step
        self.isOptional = isOptional
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.plan = nil
    }

    var kind: Kind {
        get { Kind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }

    /// "Number · hours", "Scale · 1–5", "Number · kg · optional".
    var summary: String {
        var parts: [String]
        switch kind {
        case .number: parts = ["Number"] + (unit.map { [$0] } ?? [])
        case .scale: parts = ["Scale", "1–5"]
        case .text: parts = ["Text"]
        }
        if isOptional { parts.append("optional") }
        return parts.joined(separator: " · ")
    }
}
