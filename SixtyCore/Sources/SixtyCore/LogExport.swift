import Foundation

/// Builds the CSV log: one row per plan day so far, whether or not
/// anything was logged, with a column for every activity and question the
/// plan has ever had (archived ones included, so old days keep their data).
public enum LogExport {
    public struct Column: Equatable, Sendable {
        public let id: UUID
        public let title: String

        public init(id: UUID, title: String) {
            self.id = id
            self.title = title
        }
    }

    public struct Day: Equatable, Sendable {
        public let day: DayKey
        public let dayNumber: Int
        /// Nil when nothing was logged that day.
        public let progress: DayProgress?
        public let answers: [UUID: String]
        public let note: String
        public let photoFilename: String?

        public init(day: DayKey, dayNumber: Int, progress: DayProgress?,
                    answers: [UUID: String] = [:], note: String = "", photoFilename: String? = nil) {
            self.day = day
            self.dayNumber = dayNumber
            self.progress = progress
            self.answers = answers
            self.note = note
            self.photoFilename = photoFilename
        }
    }

    /// Activity cells: "1" ticked, "0" planned but not ticked, blank if the
    /// activity wasn't part of the plan that day.
    public static func csv(days: [Day], activities: [Column], questions: [Column]) -> String {
        let header = ["date", "day", "complete", "activities done"]
            + activities.map(\.title)
            + questions.map(\.title)
            + ["note", "photo"]

        let rows = days.map { day -> [String] in
            let progress = day.progress
            let planned = Set(progress?.plannedActivityIDs ?? [])
            var row = [
                day.day.rawValue,
                String(day.dayNumber),
                progress?.isComplete == true ? "yes" : "no",
                progress.map { "\($0.activitiesDone) of \($0.activitiesTotal)" } ?? "",
            ]
            row += activities.map { column in
                guard planned.contains(column.id) else { return "" }
                return progress?.completedActivityIDs.contains(column.id) == true ? "1" : "0"
            }
            row += questions.map { day.answers[$0.id] ?? "" }
            row += [day.note, day.photoFilename ?? ""]
            return row
        }
        return CSVWriter.csv(header: header, rows: rows)
    }
}
