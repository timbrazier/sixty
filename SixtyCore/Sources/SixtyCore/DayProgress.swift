import Foundation

/// What was asked of a day and what was done, judged against that day's own
/// snapshot of activities and questions so later plan edits don't rewrite it.
public struct DayProgress: Equatable, Sendable {
    public var plannedActivityIDs: [UUID]
    public var completedActivityIDs: Set<UUID>
    /// Questions that must be answered for the day to count. Optional
    /// questions (e.g. weight) are left out.
    public var requiredQuestionIDs: [UUID]
    public var answeredQuestionIDs: Set<UUID>

    public init(plannedActivityIDs: [UUID],
                completedActivityIDs: Set<UUID>,
                requiredQuestionIDs: [UUID],
                answeredQuestionIDs: Set<UUID>) {
        self.plannedActivityIDs = plannedActivityIDs
        self.completedActivityIDs = completedActivityIDs
        self.requiredQuestionIDs = requiredQuestionIDs
        self.answeredQuestionIDs = answeredQuestionIDs
    }

    public var activitiesDone: Int {
        plannedActivityIDs.filter(completedActivityIDs.contains).count
    }

    public var activitiesTotal: Int { plannedActivityIDs.count }

    public var questionsAnswered: Int {
        requiredQuestionIDs.filter(answeredQuestionIDs.contains).count
    }

    public var questionsTotal: Int { requiredQuestionIDs.count }

    public var openActivityIDs: [UUID] {
        plannedActivityIDs.filter { !completedActivityIDs.contains($0) }
    }

    /// Every planned activity ticked and every required question answered.
    public var isComplete: Bool {
        activitiesDone == activitiesTotal && questionsAnswered == questionsTotal
    }

    public var hasAnyProgress: Bool {
        activitiesDone > 0 || questionsAnswered > 0
    }
}

/// How a day shows in the Progress grid and the day strip.
public enum DayStatus: Equatable, Sendable {
    /// Every activity ticked and every required question answered.
    case complete
    /// Something logged but not everything; counts are activities.
    case partial(done: Int, total: Int)
    /// A past day with nothing logged.
    case missed
    /// Today, nothing logged yet.
    case open
    /// After today: can be viewed, not logged.
    case upcoming

    public static func of(day: DayKey, today: DayKey, progress: DayProgress?) -> DayStatus {
        if day > today { return .upcoming }
        if let progress, progress.isComplete { return .complete }
        if let progress, progress.hasAnyProgress {
            return .partial(done: progress.activitiesDone, total: progress.activitiesTotal)
        }
        return day == today ? .open : .missed
    }
}
