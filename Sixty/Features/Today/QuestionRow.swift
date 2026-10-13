import SwiftUI

/// One daily question. Answers are stored as text: numbers as "7.5", the
/// scale as "1"–"5". An empty string means unanswered.
struct QuestionRow: View {
    let question: Question
    @Binding var answer: String
    /// Last time's answer, used as the starting value for "Add".
    let suggestion: String?
    let isLocked: Bool

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Tokens.Space.xs))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Tokens.Space.s))
        layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(question.prompt)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Colour.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(Tokens.Font.footnoteRegular)
                        .foregroundStyle(Tokens.Colour.ink2)
                }
            }
            .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
            .layoutPriority(1)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            control
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.xs)
        .frame(minHeight: Tokens.Size.row)
        .disabled(isLocked)
        .opacity(isLocked ? 0.5 : 1)
        .contextMenu {
            if !answer.isEmpty && !isLocked {
                Button("Clear answer", systemImage: "xmark.circle") { answer = "" }
            }
        }
    }

    /// "hours", "kg · optional", "1 low · 5 high".
    private var subtitle: String? {
        var parts: [String] = []
        switch question.kind {
        case .number: if let unit = question.unit { parts.append(unit) }
        case .scale: parts.append("1 low · 5 high")
        case .text: break
        }
        if question.isOptional { parts.append("optional") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var control: some View {
        switch question.kind {
        case .number:
            NumberControl(answer: $answer, step: question.step, suggestion: suggestion, label: question.prompt)
        case .scale:
            ScaleControl(answer: $answer, label: question.prompt)
        case .text:
            TextField("Answer", text: $answer, axis: .vertical)
                .font(Tokens.Font.body)
                .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
                .foregroundStyle(Tokens.Colour.ink)
        }
    }
}

/// "−  7.5  +", or an "Add" button until there's a value. The number can
/// also be typed.
struct NumberControl: View {
    @Binding var answer: String
    let step: Double
    let suggestion: String?
    let label: String

    @FocusState private var isTyping: Bool

    var body: some View {
        // Stay on the number field while typing, even if it's cleared.
        if answer.isEmpty && !isTyping {
            Button {
                answer = suggestion ?? NumberAnswer.format(0, step: step)
            } label: {
                Text("Add")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Colour.ink2)
                    .padding(.horizontal, Tokens.Space.m)
                    .frame(minHeight: Tokens.Size.stepperVisual)
                    .background(Tokens.Colour.surface2, in: RoundedRectangle(cornerRadius: Tokens.Radius.gridCell + 3))
                    .frame(minHeight: Tokens.Size.minHit)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(label)")
        } else {
            HStack(spacing: Tokens.Space.xs) {
                stepButton("minus", label: "Less") { nudge(-1) }
                TextField("0", text: typedAnswer)
                    .keyboardType(.decimalPad)
                    .focused($isTyping)
                    .font(Tokens.Font.stat(26))
                    .foregroundStyle(Tokens.Colour.ink)
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 44, maxWidth: 72)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel(label)
                stepButton("plus", label: "More") { nudge(1) }
            }
            .sensoryFeedback(.selection, trigger: answer)
        }
    }

    /// Typed numbers keep a full stop as the separator.
    private var typedAnswer: Binding<String> {
        Binding { answer } set: { answer = $0.replacingOccurrences(of: ",", with: ".") }
    }

    private func nudge(_ direction: Double) {
        let current = NumberAnswer.parse(answer) ?? 0
        // Snap to the step grid so 7.3 + 0.5 lands on 7.5, not 7.8. The
        // tolerance stops 7.5 / 0.1 = 74.999… counting as off the grid.
        let steps = current / step
        let onGrid = abs(steps - steps.rounded()) < 1e-6
        let base = onGrid ? steps.rounded() : (direction > 0 ? steps.rounded(.down) : steps.rounded(.up))
        answer = NumberAnswer.format(max(0, (base + direction) * step), step: step)
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Tokens.Colour.ink)
                .frame(width: Tokens.Size.stepperVisual, height: Tokens.Size.stepperVisual)
                .background(Tokens.Colour.surface2, in: Circle())
                .frame(width: Tokens.Size.minHit, height: Tokens.Size.minHit)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(label)
    }
}

/// 1–5 chips; tapping the selected one clears it.
struct ScaleControl: View {
    @Binding var answer: String
    let label: String

    var body: some View {
        HStack(spacing: Tokens.Space.xxs + 2) {
            ForEach(1...5, id: \.self) { value in
                let isSelected = answer == String(value)
                Button {
                    answer = isSelected ? "" : String(value)
                } label: {
                    Text("\(value)")
                        .font(Tokens.Font.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Tokens.Colour.accentInk : Tokens.Colour.ink2)
                        .frame(width: 34, height: 36)
                        .background(isSelected ? Tokens.Colour.accent : Tokens.Colour.surface2,
                                    in: RoundedRectangle(cornerRadius: Tokens.Radius.gridCell + 1))
                        .frame(minHeight: Tokens.Size.minHit)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(label) \(value)")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .sensoryFeedback(.selection, trigger: answer)
    }
}

/// Number answers are stored with a full stop as the decimal separator,
/// whatever the device locale, so the CSV export is consistent.
enum NumberAnswer {
    static func parse(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    static func format(_ value: Double, step: Double) -> String {
        let decimals = step >= 1 ? 0 : (step >= 0.1 ? 1 : 2)
        let text = String(format: "%.\(decimals)f", value)
        // "8.0" reads better as "8".
        if decimals > 0, text.hasSuffix(".0") { return String(text.dropLast(2)) }
        return text
    }
}
