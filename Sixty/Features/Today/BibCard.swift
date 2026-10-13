import SwiftUI

/// The race-bib card: "DAY", the big day number "14 of 60", the date, and
/// the progress ring. At accessibility text sizes the ring moves below the
/// number; the number itself stops growing at AX1.
struct BibCard: View {
    let label: String
    let dayNumber: Int
    let length: Int
    let date: String
    let done: Int
    let total: Int
    let isComplete: Bool
    var isLocked = false

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Bib {
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Day").sectionLabelStyle()
                    Spacer()
                    Text(isLocked ? "Locked" : label)
                        .font(Tokens.Font.caption2.monospaced())
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(Tokens.Colour.ink3)
                        .lineLimit(1)
                }

                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Tokens.Space.s))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: Tokens.Space.s))
                layout {
                    VStack(alignment: .leading, spacing: 0) {
                        DayNumber(number: dayNumber, length: length, isDimmed: isLocked)
                        Text(date)
                            .font(Tokens.Font.subheadline)
                            .foregroundStyle(Tokens.Colour.ink2)
                    }
                    Spacer(minLength: 0)
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundStyle(Tokens.Colour.ink3)
                            .frame(width: 56, height: 56)
                            .background(Tokens.Colour.surface2, in: Circle())
                            .accessibilityLabel("Locked")
                    } else {
                        ProgressRing(done: done, total: total, isComplete: isComplete)
                            .frame(width: 92, height: 92)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Day \(dayNumber) of \(length), \(date). \(done) of \(total) activities done\(isComplete ? ", day complete" : "")")
    }
}

/// "14 of 60" in Barlow Condensed.
struct DayNumber: View {
    let number: Int
    let length: Int
    var size: CGFloat = 124
    var isDimmed = false

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: Tokens.Space.xs) {
            Text("\(number)")
                .font(Tokens.Font.bib(size))
                .foregroundStyle(isDimmed ? Tokens.Colour.ink3 : Tokens.Colour.ink)
                .padding(.vertical, -size * 0.12) // the design sets this at 0.8 line height
            Text("of \(length)")
                .font(Tokens.Font.stat(size * 0.29))
                .foregroundStyle(Tokens.Colour.ink3)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// White card with 20 pt corners and the small corner "pin holes" of a race bib.
struct Bib<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(Tokens.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.Colour.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.bib))
            .overlay {
                GeometryReader { proxy in
                    let inset: CGFloat = 10
                    ForEach(0..<4, id: \.self) { corner in
                        Circle()
                            .fill(Tokens.Colour.line)
                            .frame(width: 5, height: 5)
                            .position(x: corner % 2 == 0 ? inset : proxy.size.width - inset,
                                      y: corner < 2 ? inset : proxy.size.height - inset)
                    }
                }
                .accessibilityHidden(true)
            }
    }
}

/// Segmented ring: one segment per activity, closing into a full ring with a
/// check when the day is complete.
struct ProgressRing: View {
    let done: Int
    let total: Int
    let isComplete: Bool
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(Tokens.Colour.surface2, lineWidth: lineWidth)

            if isComplete {
                Circle()
                    .stroke(Tokens.Colour.accent, lineWidth: lineWidth)
            } else if total > 0 {
                ForEach(0..<total, id: \.self) { index in
                    let gap = total > 1 ? 0.012 : 0
                    let start = Double(index) / Double(total) + gap
                    let end = Double(index + 1) / Double(total) - gap
                    Circle()
                        .trim(from: start, to: index < done ? end : start)
                        .stroke(Tokens.Colour.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
            }

            VStack(spacing: 0) {
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Tokens.Colour.accent)
                        .transition(.scale.combined(with: .opacity))
                    Text("\(done)/\(total)")
                        .font(Tokens.Font.caption2)
                        .foregroundStyle(Tokens.Colour.ink2)
                } else {
                    Text("\(done)/\(total)")
                        .font(Tokens.Font.stat(26))
                        .foregroundStyle(Tokens.Colour.ink)
                        .contentTransition(.numericText())
                    Text("done")
                        .font(Tokens.Font.caption2)
                        .foregroundStyle(Tokens.Colour.ink2)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
        .padding(lineWidth / 2)
        .animation(Tokens.Motion.ring, value: done)
        .animation(Tokens.Motion.ring, value: isComplete)
        .accessibilityHidden(true)
    }
}

/// "Day 14 complete · Logged in 1:48 · Day 15 opens tomorrow"
struct DayCompleteBanner: View {
    let dayNumber: Int
    let detail: String

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            TickMark(isOn: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Day \(dayNumber) complete")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Colour.ink)
                if !detail.isEmpty {
                    Text(detail)
                        .font(Tokens.Font.subheadline)
                        .foregroundStyle(Tokens.Colour.ink2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.m)
        .background(Tokens.Colour.accentSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.banner))
        .accessibilityElement(children: .combine)
    }
}
