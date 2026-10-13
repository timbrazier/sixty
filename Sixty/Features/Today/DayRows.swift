import SwiftUI

/// "ACTIVITIES ........ 3 OF 5"
struct SectionHeader: View {
    let title: String
    var trailing: String?

    init(_ title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let trailing {
                Text(trailing).contentTransition(.numericText())
            }
        }
        .sectionLabelStyle()
        .padding(.horizontal, Tokens.Space.m)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Rows on a white card with 14 pt corners.
struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Tokens.Colour.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.list))
    }
}

struct CardDivider: View {
    var leading: CGFloat = Tokens.Space.m
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(Tokens.Colour.line)
            .frame(height: 1 / displayScale)
            .padding(.leading, leading)
    }
}

/// A checklist row. The whole 52 pt row is the tap target.
struct ActivityRow: View {
    let title: String
    let target: String?
    let isDone: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s) {
                TickMark(isOn: isDone, isUpcoming: isLocked)
                Text(title)
                    .font(Tokens.Font.body)
                    .foregroundStyle(isLocked ? Tokens.Colour.ink3 : Tokens.Colour.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let target {
                    Text(target)
                        .font(Tokens.Font.subheadline)
                        .foregroundStyle(Tokens.Colour.ink2)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal, Tokens.Space.m)
            .padding(.vertical, Tokens.Space.xs)
            .frame(minHeight: Tokens.Size.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue([target, isDone ? "done" : "not done"].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(isDone ? [.isButton, .isSelected] : [.isButton])
    }
}

/// The tick: the circle fills from the centre with a slight overshoot
/// (160 ms), then the check stroke draws in (200 ms). Unticking reverses at once.
struct TickMark: View {
    let isOn: Bool
    /// Future days: a dashed outline that can't be ticked.
    var isUpcoming = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isUpcoming ? Tokens.Colour.line2 : Tokens.Colour.ink3,
                              style: StrokeStyle(lineWidth: 1.5, dash: isUpcoming ? [3, 3] : []))
                .opacity(isOn ? 0 : 1)
            Circle()
                .fill(Tokens.Colour.accent)
                .scaleEffect(isOn ? 1 : 0.01)
                .opacity(isOn ? 1 : 0)
                .animation(isOn ? Tokens.Motion.tickFill : nil, value: isOn)
            CheckShape()
                .trim(from: 0, to: isOn ? 1 : 0)
                .stroke(Tokens.Colour.accentInk, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .padding(7)
                .animation(isOn ? Tokens.Motion.tickStroke.delay(0.1) : nil, value: isOn)
        }
        .frame(width: 26, height: 26)
    }
}

struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.40, y: rect.minY + rect.height * 0.85))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.95, y: rect.minY + rect.height * 0.18))
        return path
    }
}

/// "Photo ✓", "Questions 3/3", "Note ✓" on a completed day.
struct FoldChip: View {
    let title: String
    /// nil shows no mark; true a check; false nothing (still to do).
    let isDone: Bool?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.xxs) {
                Text(title)
                if isDone == true {
                    Image(systemName: "checkmark").font(.caption.weight(.bold))
                }
            }
            .font(Tokens.Font.subheadline.weight(.semibold))
            .foregroundStyle(Tokens.Colour.ink)
            .padding(.horizontal, Tokens.Space.s)
            .frame(minHeight: Tokens.Size.minHit - 8)
            .background(Tokens.Colour.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.chip))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows this section")
    }
}

/// The day's note.
struct NoteField: View {
    @Binding var text: String
    let isLocked: Bool

    var body: some View {
        TextField("How did it go?", text: $text, axis: .vertical)
            .font(Tokens.Font.body)
            .foregroundStyle(Tokens.Colour.ink)
            .lineLimit(3...)
            .padding(Tokens.Space.m)
            .background(Tokens.Colour.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.list))
            .disabled(isLocked)
    }
}

/// "Editing a past day · Changes save automatically.   [Today]"
struct PastDayBanner: View {
    let onToday: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Editing a past day")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Colour.ink)
                Text("Changes save automatically.")
                    .font(Tokens.Font.subheadline)
                    .foregroundStyle(Tokens.Colour.ink2)
            }
            Spacer(minLength: 0)
            Button("Today", action: onToday)
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Colour.ink)
                .padding(.horizontal, Tokens.Space.m)
                .frame(minHeight: Tokens.Size.minHit - 6)
                .background(Tokens.Colour.surface, in: Capsule())
                .buttonStyle(.plain)
        }
        .padding(Tokens.Space.m)
        .background(Tokens.Colour.surface2, in: RoundedRectangle(cornerRadius: Tokens.Radius.banner))
    }
}
