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
                TickMark(isOn: isDone)
                    .opacity(isLocked ? 0.4 : 1)
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

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Tokens.Colour.ink3, lineWidth: 1.5)
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

/// Empty photo slot. Capture arrives in step 4.
struct PhotoSlot: View {
    let isLocked: Bool

    var body: some View {
        VStack(spacing: Tokens.Space.xs) {
            Image(systemName: "camera")
                .font(.title3)
            Text(isLocked ? "Photo" : "Add today's photo")
                .font(Tokens.Font.headline)
        }
        .foregroundStyle(isLocked ? Tokens.Colour.ink3 : Tokens.Colour.accent)
        .frame(maxWidth: .infinity, minHeight: 120)
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.photo)
                .strokeBorder(Tokens.Colour.line2, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .accessibilityElement(children: .combine)
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
