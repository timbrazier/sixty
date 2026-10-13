import SwiftUI
import SwiftData
import SixtyCore

/// Seven days around the one showing, each with its status mark. Future
/// days can be opened here read-only.
struct DayStrip: View {
    let plan: Plan
    let selected: DayKey
    let onSelect: (DayKey) -> Void

    @Environment(\.today) private var today
    @Query private var entries: [DayEntry]

    var body: some View {
        let byDay = Dictionary(entries.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        HStack(spacing: Tokens.Space.xxs + 2) {
            ForEach(days, id: \.self) { day in
                let status = DayStatus.of(day: day, today: today, progress: byDay[day]?.progress)
                Button { onSelect(day) } label: {
                    VStack(spacing: 2) {
                        Text(day == today ? "Today" : day.weekdayName)
                            .font(Tokens.Font.caption2)
                            .foregroundStyle(Tokens.Colour.ink2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(plan.calendar.dayNumber(for: day))")
                            .font(Tokens.Font.stat(22))
                            .foregroundStyle(day > today ? Tokens.Colour.ink3 : Tokens.Colour.ink)
                        StatusMark(status: status)
                    }
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(Tokens.Colour.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.chip))
                    .overlay {
                        if day == selected {
                            RoundedRectangle(cornerRadius: Tokens.Radius.chip)
                                .strokeBorder(Tokens.Colour.ink, lineWidth: 2)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Day \(plan.calendar.dayNumber(for: day)), \(day.longName), \(status.spoken)")
                .accessibilityAddTraits(day == selected ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.bottom, Tokens.Space.xs)
        .background(Tokens.Colour.bg)
    }

    /// Seven days including `selected`, ending at tomorrow where possible
    /// (as in the design), kept inside the plan.
    private var days: [DayKey] {
        let count = min(7, plan.lengthDays)
        let preferredLast = max(selected, today.adding(days: 1))
        var first = min(selected.adding(days: -3), preferredLast.adding(days: -(count - 1)))
        first = max(first, plan.calendar.startDay)
        first = min(first, plan.calendar.endDay.adding(days: -(count - 1)))
        return (0..<count).map { first.adding(days: $0) }
    }
}

/// The small mark under a day: a dot when complete, a half dot when
/// partial, a grey dot when missed, a ring for today, a lock for the future.
struct StatusMark: View {
    let status: DayStatus

    var body: some View {
        Group {
            switch status {
            case .complete:
                Circle().fill(Tokens.Colour.accent)
            case .partial:
                Circle()
                    .stroke(Tokens.Colour.accent, lineWidth: 1.5)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Tokens.Colour.accent).frame(height: 4)
                    }
                    .clipShape(Circle())
            case .missed:
                Circle().fill(Tokens.Colour.hatch)
            case .open:
                Circle().stroke(Tokens.Colour.ink3, lineWidth: 1.5)
            case .upcoming:
                Image(systemName: "lock.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Tokens.Colour.ink3)
            }
        }
        .frame(width: 8, height: 8)
        .accessibilityHidden(true)
    }
}

extension DayStatus {
    /// For VoiceOver: "complete", "3 of 5 done", "missed".
    var spoken: String {
        switch self {
        case .complete: "complete"
        case .partial(let done, let total): "\(done) of \(total) done"
        case .missed: "missed"
        case .open: "not logged yet"
        case .upcoming: "upcoming"
        }
    }
}
