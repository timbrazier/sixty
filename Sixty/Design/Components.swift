import SwiftUI

/// Full-width accent button pinned to the bottom of a screen: "Continue", "Start plan".
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.Font.headline)
            .foregroundStyle(Tokens.Colour.accentInk)
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.primaryButton)
            .background(Tokens.Colour.accent.opacity(isEnabled ? 1 : 0.4),
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.button))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

/// The bottom bar holding a primary button over the screen background.
struct BottomActionBar<Label: View>: View {
    let isEnabled: Bool
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) { label }
            .buttonStyle(.primary)
            .disabled(!isEnabled)
            .padding(.horizontal, Tokens.Space.m)
            .padding(.vertical, Tokens.Space.s)
            .background(Tokens.Colour.bg)
    }
}

/// Segmented choice on a surface-2 track with the selected option on a
/// raised surface pill: the plan length picker ("30 · 60 days · 90 · Custom").
struct SegmentedChoice<Value: Hashable>: View {
    struct Option {
        let value: Value
        let label: String
        /// Shown instead of `label` while selected, e.g. "60 days" for "60".
        var selectedLabel: String?
    }

    @Binding var selection: Value
    let options: [Option]

    var body: some View {
        HStack(spacing: Tokens.Space.xxs) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selection = option.value }
                } label: {
                    Text(isSelected ? (option.selectedLabel ?? option.label) : option.label)
                        .font(isSelected ? Tokens.Font.subheadline.weight(.semibold) : Tokens.Font.subheadline)
                        .foregroundStyle(isSelected ? Tokens.Colour.ink : Tokens.Colour.ink2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: Tokens.Size.minHit - 8)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: Tokens.Radius.chip - 3)
                                    .fill(Tokens.Colour.surface)
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(Tokens.Space.xxs)
        .background(Tokens.Colour.surface2, in: RoundedRectangle(cornerRadius: Tokens.Radius.chip))
    }
}

/// A reminder row: label, time chip and switch ("Morning nudge  06:45  ●").
struct ReminderRow: View {
    let title: String
    @Binding var isOn: Bool
    /// Minutes after midnight.
    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Text(title)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Colour.ink)
            Spacer(minLength: Tokens.Space.xs)
            DatePicker(title, selection: timeBinding, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .disabled(!isOn)
                .opacity(isOn ? 1 : 0.5)
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .tint(Tokens.Colour.accent)
        }
        .frame(minHeight: Tokens.Size.row)
    }

    /// The DatePicker works in `Date`s; the plan stores minutes after midnight.
    private var timeBinding: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }
}

/// "Add activity" / "Add question" row with the accent plus.
struct AddRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title).foregroundStyle(Tokens.Colour.accent)
            } icon: {
                Image(systemName: "plus.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Tokens.Colour.accentInk, Tokens.Colour.accent)
            }
            .font(Tokens.Font.body)
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.row, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// List styling shared by the setup and settings screens: screen
    /// background behind inset-grouped surface rows.
    func sixtyListStyle() -> some View {
        self.listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Tokens.Colour.bg)
    }

    /// A row on a surface background, for use inside `sixtyListStyle` lists.
    func surfaceRow() -> some View {
        self.listRowBackground(Tokens.Colour.surface)
            .listRowSeparatorTint(Tokens.Colour.line)
    }
}
