import Foundation
import Observation
import SixtyCore

/// Which tab is showing, and requests to open a particular day on Today
/// (from the Progress grid now, and notification taps in step 7).
@MainActor
@Observable
final class AppRouter {
    enum Tab: Hashable {
        case today, progress, photos, settings
    }

    var tab: Tab = .today
    /// Picked up and cleared by the Today tab.
    var requestedDay: DayKey?

    func open(_ day: DayKey) {
        requestedDay = day
        tab = .today
    }
}
