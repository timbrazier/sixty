import Foundation
import SwiftData

/// Something ticked off each day, e.g. "Morning run · 5 km".
/// Archived rather than deleted, so past days still show what they had.
///
/// Each one is either a non-negotiable, which every day needs for it to
/// count as complete, or a bonus habit, which is tracked but never holds a
/// day back.
@Model
final class Activity {
    /// Section names, used everywhere activities are listed.
    enum Group {
        static let core = "Non-negotiables"
        static let bonus = "Bonus habits"
    }

    @Attribute(.unique) var id: UUID
    var title: String
    /// Free text shown on the right of the row: "5 km", "3 × 20".
    var target: String?
    var sortOrder: Int
    var isArchived: Bool
    /// Bonus habits don't count towards a complete day. Activities from
    /// before the split default to non-negotiables.
    var isBonus: Bool = false
    var plan: Plan?

    init(id: UUID = UUID(), title: String, target: String? = nil, sortOrder: Int,
         isBonus: Bool = false, isArchived: Bool = false) {
        self.id = id
        self.title = title
        self.target = target
        self.sortOrder = sortOrder
        self.isBonus = isBonus
        self.isArchived = isArchived
        self.plan = nil
    }
}
