import Foundation
import SwiftData
import SixtyCore

/// Writes export files to a temporary folder for the share sheet: the CSV
/// log, and a zip of every photo named by day.
@MainActor
enum Exporter {
    enum ExportError: LocalizedError {
        case noPlan, noPhotos, zipFailed

        var errorDescription: String? {
            switch self {
            case .noPlan: "There's no plan to export."
            case .noPhotos: "There are no photos to export yet."
            case .zipFailed: "Couldn't put the photos together."
            }
        }
    }

    /// "Sixty – Autumn reset.csv": one row per day so far.
    static func csv(in context: ModelContext, today: DayKey = .today()) throws -> URL {
        let store = EntryStore(context: context)
        guard let plan = store.plan() else { throw ExportError.noPlan }
        let entries = store.entriesByDay()

        // Every day so far; after the plan ends, all of it.
        let days = plan.calendar.daysSoFar(today: today).map { day in
            let entry = entries[day]
            var answers: [UUID: String] = [:]
            for (key, value) in entry?.answers ?? [:] {
                if let id = UUID(uuidString: key) { answers[id] = value }
            }
            return LogExport.Day(day: day,
                                 dayNumber: plan.calendar.dayNumber(for: day),
                                 progress: entry?.progress,
                                 answers: answers,
                                 note: entry?.journal ?? "",
                                 photoFilename: entry?.photoFilename.map { photoName(day: day, plan: plan, filename: $0) })
        }
        let activities = plan.activities.sorted { $0.sortOrder < $1.sortOrder }.map {
            LogExport.Column(id: $0.id, title: $0.isArchived ? "\($0.title) (removed)" : $0.title)
        }
        let questions = plan.questions.sorted { $0.sortOrder < $1.sortOrder }.map {
            LogExport.Column(id: $0.id, title: $0.isArchived ? "\($0.prompt) (removed)" : $0.prompt)
        }

        let text = LogExport.csv(days: days, activities: activities, questions: questions)
        let url = try exportFolder().appending(path: "\(baseName(plan)).csv")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// "Sixty – Autumn reset photos.zip" with files like "Day 01 – 2026-09-30.jpg".
    static func photosZip(in context: ModelContext) async throws -> URL {
        let store = EntryStore(context: context)
        guard let plan = store.plan() else { throw ExportError.noPlan }
        let photos = store.entriesByDay()
            .compactMap { day, entry in entry.photoFilename.map { (day, $0) } }
            .filter { plan.calendar.contains($0.0) }
            .sorted { $0.0 < $1.0 }
        guard !photos.isEmpty else { throw ExportError.noPhotos }

        let folderName = "\(baseName(plan)) photos"
        let files = photos.map { (source: PhotoStore.url(for: $0.1), name: photoName(day: $0.0, plan: plan, filename: $0.1)) }
        let root = try exportFolder()

        return try await Task.detached(priority: .userInitiated) {
            let folder = root.appending(path: folderName, directoryHint: .isDirectory)
            let fileManager = FileManager.default
            try? fileManager.removeItem(at: folder)
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            for file in files where fileManager.fileExists(atPath: file.source.path) {
                try fileManager.copyItem(at: file.source, to: folder.appending(path: file.name))
            }
            return try Exporter.archive(folder, to: root.appending(path: "\(folderName).zip"))
        }.value
    }

    // MARK: Private

    /// "Day 01 – 2026-09-30.jpg"
    private static func photoName(day: DayKey, plan: Plan, filename: String) -> String {
        let width = String(plan.lengthDays).count
        let number = String(plan.calendar.dayNumber(for: day))
        let padded = String(repeating: "0", count: max(0, width - number.count)) + number
        return "Day \(padded) – \(day.rawValue).jpg"
    }

    private static func baseName(_ plan: Plan) -> String {
        let safe = plan.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return "Sixty – \(safe)"
    }

    private static func exportFolder() throws -> URL {
        let folder = URL.temporaryDirectory.appending(path: "Export", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Zips a folder with the system's own archiver: asking a file
    /// coordinator for a folder "for uploading" hands back a zip of it.
    nonisolated private static func archive(_ folder: URL, to destination: URL) throws -> URL {
        var coordinatorError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinatorError) { zipURL in
            do {
                try? FileManager.default.removeItem(at: destination)
                // The zip is deleted when this block returns, so copy it out.
                try FileManager.default.copyItem(at: zipURL, to: destination)
            } catch {
                copyError = error
            }
        }
        if let error = coordinatorError ?? copyError { throw error }
        guard FileManager.default.fileExists(atPath: destination.path) else { throw ExportError.zipFailed }
        return destination
    }
}
