import Foundation
import SwiftData
import SixtyCore

/// Finds and creates day entries. Entries are only created when something is
/// logged, so browsing days never leaves empty rows behind.
@MainActor
struct EntryStore {
    let context: ModelContext

    func entry(for day: DayKey) -> DayEntry? {
        let raw = day.rawValue
        var descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate { $0.dayKey == raw })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// The entry for `day`, created with a snapshot of the plan if it doesn't exist.
    func entryForEditing(_ day: DayKey, plan: Plan) -> DayEntry {
        if let existing = entry(for: day) { return existing }
        let entry = DayEntry(day: day, plan: plan)
        context.insert(entry)
        return entry
    }

    /// Entries keyed by day, for the Progress grid and streaks.
    func entriesByDay() -> [DayKey: DayEntry] {
        let all = (try? context.fetch(FetchDescriptor<DayEntry>())) ?? []
        return Dictionary(all.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func status(of day: DayKey, today: DayKey, entries: [DayKey: DayEntry]) -> DayStatus {
        DayStatus.of(day: day, today: today, progress: entries[day]?.progress)
    }

    func completeDays(entries: [DayKey: DayEntry]) -> Set<DayKey> {
        Set(entries.values.filter(\.isComplete).map(\.day))
    }

    /// After the plan's activities or questions change, today's and any future
    /// entries take the new list; past days keep theirs.
    func refreshSnapshots(for plan: Plan, today: DayKey) {
        for (day, entry) in entriesByDay() where day >= today {
            entry.snapshot(plan)
        }
    }

    /// The single active plan. The app holds one plan at a time.
    func plan() -> Plan? {
        var descriptor = FetchDescriptor<Plan>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
