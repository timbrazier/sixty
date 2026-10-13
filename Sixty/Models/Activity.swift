import Foundation
import SwiftData

/// Something ticked off each day, e.g. "Morning run · 5 km".
/// Archived rather than deleted, so past days still show what they had.
@Model
final class Activity {
    @Attribute(.unique) var id: UUID
    var title: String
    /// Free text shown on the right of the row: "5 km", "3 × 20".
    var target: String?
    var sortOrder: Int
    var isArchived: Bool
    var plan: Plan?

    init(id: UUID = UUID(), title: String, target: String? = nil, sortOrder: Int, isArchived: Bool = false) {
        self.id = id
        self.title = title
        self.target = target
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.plan = nil
    }
}
