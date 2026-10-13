import Foundation
import Observation
import SwiftData

/// Saves the store 500 ms after the last change, and straight away when the
/// app goes to the background, so a force-quit loses at most half a second.
/// There's no save button anywhere.
@MainActor
@Observable
final class AutoSaver {
    enum State: Equatable {
        case idle
        case saving
        case saved(Date)
        case failed
    }

    private(set) var state: State = .idle
    /// Called after each successful save; notifications hook in here (step 7).
    var onSaved: (() -> Void)?

    private let context: ModelContext
    private var pending: Task<Void, Never>?

    init(context: ModelContext) {
        self.context = context
    }

    /// Something changed: show "Saving…" and save once things go quiet.
    func changed() {
        state = .saving
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: Tokens.Motion.autosaveDelay)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    /// Saves immediately if anything is waiting.
    func saveNow() {
        pending?.cancel()
        pending = nil
        guard context.hasChanges || state == .saving else { return }
        do {
            try context.save()
            state = .saved(Date())
            onSaved?()
        } catch {
            state = .failed
        }
    }
}
