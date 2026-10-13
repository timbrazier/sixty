import SwiftUI
import SwiftData
import SixtyCore

/// The last day, once complete: four stats, the whole plan in miniature,
/// and the first photo next to the last.
struct FinalSummary: View {
    let plan: Plan

    @Environment(\.today) private var today
    @Query(sort: \DayEntry.date) private var entries: [DayEntry]

    var body: some View {
        let byDay = Dictionary(entries.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        let stats = PlanStats(calendar: plan.calendar, today: today, progress: byDay.mapValues(\.progress))
        let photos = entries.filter { $0.photoFilename != nil && plan.calendar.contains($0.day) }

        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            StatTiles(tiles: [
                (stats.completionPercent.map { "\($0)%" } ?? "–", "Completion"),
                ("\(stats.completeDays)", "Full days"),
                ("\(stats.bestStreak)", "Best streak"),
                ("\(photos.count)", "Photos"),
            ])

            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                DayGrid(plan: plan, entries: byDay, compact: true)
                Text("\(stats.completeDays) complete · \(stats.partialDays) partial · \(stats.missedDays) missed")
                    .font(Tokens.Font.footnoteRegular)
                    .foregroundStyle(Tokens.Colour.ink2)
            }
            .padding(Tokens.Space.m)
            .background(Tokens.Colour.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.list))

            let first = photos.first?.day ?? plan.calendar.startDay
            let last = photos.last?.day ?? plan.calendar.endDay
            PhotoCompare(left: side(first, byDay), right: side(last, byDay))
        }
    }

    private func side(_ day: DayKey, _ byDay: [DayKey: DayEntry]) -> PhotoCompare.Side {
        PhotoCompare.Side(dayNumber: plan.calendar.dayNumber(for: day), day: day,
                          filename: byDay[day]?.photoFilename)
    }
}
