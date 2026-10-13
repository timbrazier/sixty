import SwiftUI
import SixtyCore

private struct TodayKey: EnvironmentKey {
    static var defaultValue: DayKey { .today() }
}

extension EnvironmentValues {
    /// The current local calendar day. Set once at the root and refreshed when
    /// the app comes to the foreground or the day rolls over, so every screen
    /// agrees on what "today" is. Previews pin it to a fixed day.
    var today: DayKey {
        get { self[TodayKey.self] }
        set { self[TodayKey.self] = newValue }
    }
}
