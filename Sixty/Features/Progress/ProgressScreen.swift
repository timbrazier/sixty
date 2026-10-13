import SwiftUI
import SwiftData
import SixtyCore

/// The Progress tab: completion, streak and days to go, the whole plan as a
/// grid of days, and a card for the day you tap with a way to open it.
struct ProgressScreen: View {
    let plan: Plan

    @Environment(\.today) private var today
    @Environment(AppRouter.self) private var router
    @Query private var entries: [DayEntry]
    @State private var selected: DayKey?

    var body: some View {
        let byDay = Dictionary(entries.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        let stats = PlanStats(calendar: plan.calendar, today: today, progress: byDay.mapValues(\.progress))
        let focus = selected ?? min(max(today, plan.calendar.startDay), plan.calendar.endDay)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s) {
                    Text(subtitle)
                        .font(Tokens.Font.subheadline)
                        .foregroundStyle(Tokens.Colour.ink2)
                        .padding(.bottom, Tokens.Space.xs)

                    StatTiles(tiles: [
                        (stats.completionPercent.map { "\($0)%" } ?? "–", "Completion"),
                        ("\(stats.currentStreak)", "Day streak"),
                        ("\(stats.daysToGo)", "Days to go"),
                    ])

                    VStack(alignment: .leading, spacing: Tokens.Space.m) {
                        DayGrid(plan: plan, entries: byDay, selected: focus) { day in
                            withAnimation(.snappy(duration: 0.2)) { selected = day }
                        }
                        GridLegend()
                    }
                    .padding(Tokens.Space.m)
                    .background(Tokens.Colour.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.list))

                    DayDetailCard(plan: plan, day: focus, entry: byDay[focus]) {
                        router.open(focus)
                    }
                }
                .padding(.horizontal, Tokens.Space.m)
                .padding(.bottom, Tokens.Space.xl)
            }
            .background(Tokens.Colour.bg)
            .navigationTitle("Progress")
            .toolbarBackground(Tokens.Colour.bg, for: .navigationBar)
        }
    }

    /// "Autumn reset · Day 14 of 60"
    private var subtitle: String {
        switch plan.calendar.phase(on: today) {
        case .notStarted(let daysToGo):
            "\(plan.name) · starts in \(daysToGo) day\(daysToGo == 1 ? "" : "s")"
        case .inProgress(let number):
            "\(plan.name) · Day \(number) of \(plan.lengthDays)"
        case .finished:
            "\(plan.name) · finished \(plan.calendar.endDay.longName)"
        }
    }
}

/// Two to four number tiles: "86% Completion", "4 Day streak".
struct StatTiles: View {
    let tiles: [(value: String, label: String)]
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Tokens.Space.xs))
            : AnyLayout(HStackLayout(spacing: Tokens.Space.xs))
        layout {
            ForEach(tiles.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 2) {
                    Text(tiles[index].value)
                        .font(Tokens.Font.stat(tiles.count > 3 ? 28 : 36))
                        .foregroundStyle(Tokens.Colour.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(tiles[index].label)
                        .font(Tokens.Font.footnoteRegular)
                        .foregroundStyle(Tokens.Colour.ink2)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Tokens.Space.s)
                .background(Tokens.Colour.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.list))
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// The plan as a 10-column grid of day cells.
struct DayGrid: View {
    let plan: Plan
    let entries: [DayKey: DayEntry]
    var selected: DayKey?
    var compact = false
    var onSelect: ((DayKey) -> Void)?

    @Environment(\.today) private var today

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: compact ? 4 : 5), count: 10)
        LazyVGrid(columns: columns, spacing: compact ? 4 : 5) {
            ForEach(plan.calendar.days, id: \.self) { day in
                let number = plan.calendar.dayNumber(for: day)
                let status = DayStatus.of(day: day, today: today, progress: entries[day]?.progress)
                DayCell(number: number, status: status, isToday: day == today,
                        isSelected: day == selected, showsNumber: !compact, aspect: compact ? 1.5 : 1)
                    .onTapGesture { onSelect?(day) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Day \(number), \(day.longName), \(status.spoken)")
                    .accessibilityAddTraits(onSelect == nil ? [] : (day == selected ? [.isButton, .isSelected] : [.isButton]))
                    .accessibilityAction { onSelect?(day) }
            }
        }
    }
}

/// One square: solid accent when complete, half-filled when partial,
/// hatched when missed, dashed outline when upcoming. Today has an ink
/// underline; the selected day an ink outline.
struct DayCell: View {
    let number: Int
    let status: DayStatus
    let isToday: Bool
    let isSelected: Bool
    var showsNumber = true
    /// Width over height; the final-day summary uses wider cells.
    var aspect: CGFloat = 1

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.gridCell)
        ZStack {
            switch status {
            case .complete:
                shape.fill(Tokens.Colour.accent)
            case .partial:
                shape.fill(Tokens.Colour.surface)
                    .overlay(alignment: .bottom) {
                        GeometryReader { proxy in
                            Rectangle().fill(Tokens.Colour.accent)
                                .frame(height: proxy.size.height * 0.45)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(Tokens.Colour.accent, lineWidth: 1.5))
            case .missed:
                Hatch(spacing: 6, lineWidth: 2.5, background: Tokens.Colour.surface2)
                    .clipShape(shape)
            case .open:
                shape.strokeBorder(Tokens.Colour.ink3, lineWidth: 1.5)
            case .upcoming:
                shape.strokeBorder(Tokens.Colour.line2, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            }

            if showsNumber {
                Text("\(number)")
                    .font(Tokens.Font.stat(15))
                    .foregroundStyle(numberColour)
                    .frame(maxHeight: .infinity, alignment: status.isPartial ? .top : .center)
                    .padding(.top, status.isPartial ? 3 : 0)
                    .dynamicTypeSize(...DynamicTypeSize.large)
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .padding(isSelected ? 2 : 0)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: Tokens.Radius.gridCell + 2)
                    .strokeBorder(Tokens.Colour.ink, lineWidth: 2)
            }
        }
        .overlay(alignment: .bottom) {
            if isToday {
                Capsule().fill(Tokens.Colour.ink)
                    .frame(width: 14, height: 3)
                    .offset(y: 6)
            }
        }
        .contentShape(Rectangle())
    }

    private var numberColour: Color {
        switch status {
        case .complete: Tokens.Colour.accentInk
        case .partial, .open: Tokens.Colour.ink
        case .missed, .upcoming: Tokens.Colour.ink3
        }
    }
}

extension DayStatus {
    var isPartial: Bool {
        if case .partial = self { return true }
        return false
    }
}

struct GridLegend: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.m) { items }
            VStack(alignment: .leading, spacing: Tokens.Space.xs) { items }
        }
        .font(Tokens.Font.footnoteRegular)
        .foregroundStyle(Tokens.Colour.ink2)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var items: some View {
        item("Complete", .complete)
        item("Partial", .partial(done: 1, total: 2))
        item("Missed", .missed)
        item("Upcoming", .upcoming)
        HStack(spacing: Tokens.Space.xxs) {
            Capsule().fill(Tokens.Colour.ink).frame(width: 12, height: 3)
            Text("Today")
        }
    }

    private func item(_ label: String, _ status: DayStatus) -> some View {
        HStack(spacing: Tokens.Space.xxs) {
            DayCell(number: 0, status: status, isToday: false, isSelected: false, showsNumber: false)
                .frame(width: 12, height: 12)
            Text(label)
        }
    }
}

/// "9 · Thursday 8 October · 4 of 5 / Push-ups not done · photo · note   [Open]"
struct DayDetailCard: View {
    let plan: Plan
    let day: DayKey
    let entry: DayEntry?
    let onOpen: () -> Void

    @Environment(\.today) private var today

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            Text("\(plan.calendar.dayNumber(for: day))")
                .font(Tokens.Font.stat(44))
                .foregroundStyle(day > today ? Tokens.Colour.ink3 : Tokens.Colour.ink)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Colour.ink)
                Text(detail)
                    .font(Tokens.Font.footnoteRegular)
                    .foregroundStyle(Tokens.Colour.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Open", action: onOpen)
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Colour.ink)
                .padding(.horizontal, Tokens.Space.m)
                .frame(minHeight: Tokens.Size.minHit - 4)
                .background(Tokens.Colour.surface2, in: Capsule())
                .buttonStyle(.plain)
                .accessibilityLabel("Open Day \(plan.calendar.dayNumber(for: day))")
        }
        .padding(Tokens.Space.m)
        .background(Tokens.Colour.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.list))
    }

    /// "Thursday 8 October · 4 of 5"
    private var headline: String {
        guard let progress = entry?.progress, day <= today else { return day.longName }
        return "\(day.longName) · \(progress.activitiesDone) of \(progress.activitiesTotal)"
    }

    /// "Push-ups not done · photo · note"
    private var detail: String {
        if day > today {
            let away = today.days(to: day)
            return away == 1 ? "Opens tomorrow" : "Opens in \(away) days"
        }
        guard let entry else { return day == today ? "Nothing logged yet" : "Nothing logged" }
        let progress = entry.progress
        var parts: [String] = []
        let open = progress.openActivityIDs.compactMap { plan.activity(id: $0)?.title }
        if !open.isEmpty {
            parts.append("\(NotificationCopy.joined(open)) not done")
        } else if progress.questionsAnswered < progress.questionsTotal {
            parts.append("Questions not answered")
        } else {
            parts.append("All done")
        }
        if entry.photoFilename != nil { parts.append("photo") }
        if !entry.journal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts.append("note") }
        return parts.joined(separator: " · ")
    }
}

#Preview("Progress") {
    PreviewHost { plan in ProgressScreen(plan: plan) }
}
