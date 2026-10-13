import SwiftUI
import SixtyCore

/// Before Day 1: "Starts in 3 days", what each day holds, and a way to start today.
struct PlanCountdownView: View {
    let plan: Plan
    let daysToGo: Int

    @Environment(\.modelContext) private var context
    @Environment(\.today) private var today
    @Environment(AutoSaver.self) private var saver

    var body: some View {
        VStack(spacing: 0) {
            Text(plan.name)
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Colour.ink)
                .frame(minHeight: Tokens.Size.minHit)
                .padding(.vertical, Tokens.Space.xs)
                .accessibilityAddTraits(.isHeader)

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                    Bib {
                        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Starts in").sectionLabelStyle()
                                Spacer()
                                Text(plan.name)
                                    .font(Tokens.Font.caption2.monospaced())
                                    .textCase(.uppercase)
                                    .tracking(1)
                                    .foregroundStyle(Tokens.Colour.ink3)
                                    .lineLimit(1)
                            }
                            HStack(alignment: .lastTextBaseline, spacing: Tokens.Space.xs) {
                                Text("\(daysToGo)")
                                    .font(Tokens.Font.bib())
                                    .foregroundStyle(Tokens.Colour.ink)
                                    .padding(.vertical, -15)
                                Text(daysToGo == 1 ? "day" : "days")
                                    .font(Tokens.Font.stat())
                                    .foregroundStyle(Tokens.Colour.ink3)
                            }
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            Text("Day 1 is \(plan.startDay.longName)")
                                .font(Tokens.Font.subheadline)
                                .foregroundStyle(Tokens.Colour.ink2)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                        SectionHeader("Each day")
                        Card {
                            ForEach(Array(plan.activeActivities.enumerated()), id: \.element.id) { index, activity in
                                if index > 0 { CardDivider() }
                                HStack(spacing: Tokens.Space.s) {
                                    Circle().fill(Tokens.Colour.ink3).frame(width: 6, height: 6)
                                    Text(activity.title)
                                        .font(Tokens.Font.body)
                                        .foregroundStyle(Tokens.Colour.ink)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    if let target = activity.target {
                                        Text(target)
                                            .font(Tokens.Font.subheadline)
                                            .foregroundStyle(Tokens.Colour.ink2)
                                    }
                                }
                                .padding(.horizontal, Tokens.Space.m)
                                .frame(minHeight: Tokens.Size.row - 4)
                                .accessibilityElement(children: .combine)
                            }
                        }
                        Text(footnote)
                            .font(Tokens.Font.footnoteRegular)
                            .foregroundStyle(Tokens.Colour.ink2)
                            .padding(.horizontal, Tokens.Space.m)
                    }

                    Button("Start today instead", action: startToday)
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Colour.ink)
                        .frame(maxWidth: .infinity, minHeight: Tokens.Size.primaryButton)
                        .background(Tokens.Colour.surface2, in: RoundedRectangle(cornerRadius: Tokens.Radius.button))
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, Tokens.Space.m)
                .padding(.vertical, Tokens.Space.s)
            }
        }
        .background(Tokens.Colour.bg)
    }

    /// "Plus 3 questions, a photo and a note. First nudge Wed 06:45."
    private var footnote: String {
        let count = plan.activeQuestions.count
        var text = "Plus \(count) question\(count == 1 ? "" : "s"), a photo and a note."
        if let minutes = plan.morningReminderMinutes {
            text += " First nudge \(plan.startDay.weekdayName) \(timeString(minutesAfterMidnight: minutes))."
        }
        return text
    }

    private func startToday() {
        withAnimation {
            plan.startDay = today
        }
        saver.changed()
    }
}
