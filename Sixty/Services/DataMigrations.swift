import Foundation
import SwiftData
import SixtyCore

/// One-off changes to data already on the phone, each run once.
@MainActor
enum DataMigrations {
    static func run(in context: ModelContext, today: DayKey = .today()) {
        removeSleepAndEnergy(in: context, today: today)
    }

    /// The Sleep (hours) and Energy (1–5) questions were dropped from the
    /// app. Archive them, so past days keep their answers but today and
    /// future days no longer ask.
    private static func removeSleepAndEnergy(in context: ModelContext, today: DayKey) {
        let key = "migration.removedSleepAndEnergy"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let store = EntryStore(context: context)
        guard let plan = store.plan() else { return }

        let dropped = plan.activeQuestions.filter { question in
            let prompt = question.prompt.trimmingCharacters(in: .whitespaces).lowercased()
            return (prompt == "sleep" && question.kind == .number)
                || (prompt == "energy" && question.kind == .scale)
        }
        for question in dropped { question.isArchived = true }
        if !dropped.isEmpty {
            store.refreshSnapshots(for: plan, today: today)
            try? context.save()
        }
        UserDefaults.standard.set(true, forKey: key)
    }
}
