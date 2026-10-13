import SwiftUI
import SixtyCore

/// Step 1: name, start day and length.
struct SetupBasicsStep: View {
    @Bindable var draft: PlanDraft
    @Environment(\.today) private var today
    @FocusState private var nameFocused: Bool

    var body: some View {
        List {
            Section {
                AdaptiveStack {
                    Text("Name").foregroundStyle(Tokens.Colour.ink)
                    TextField("Autumn reset", text: $draft.name)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Tokens.Colour.ink)
                        .focused($nameFocused)
                        .submitLabel(.done)
                }
                .frame(minHeight: Tokens.Size.row)
                .surfaceRow()

                DatePicker("Starts", selection: startDate, in: startRange, displayedComponents: .date)
                    .foregroundStyle(Tokens.Colour.ink)
                    .frame(minHeight: Tokens.Size.row)
                    .surfaceRow()
            } header: {
                VStack(alignment: .leading, spacing: Tokens.Space.l) {
                    SetupTitle(title: "New plan",
                               lede: "Set the basics. Everything here can be changed later in Settings.")
                    Text("Plan").sectionLabelStyle()
                }
            }

            Section {
                SegmentedChoice(selection: $draft.length, options: [
                    .init(value: .days30, label: "30", selectedLabel: "30 days"),
                    .init(value: .days60, label: "60", selectedLabel: "60 days"),
                    .init(value: .days90, label: "90", selectedLabel: "90 days"),
                    .init(value: .custom, label: "Custom"),
                ])
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if draft.length == .custom {
                    Stepper(value: $draft.customDays, in: 7...365) {
                        HStack {
                            Text("Days").foregroundStyle(Tokens.Colour.ink)
                            Spacer()
                            Text("\(draft.customDays)")
                                .monospacedDigit()
                                .foregroundStyle(Tokens.Colour.ink2)
                        }
                    }
                    .frame(minHeight: Tokens.Size.row)
                    .surfaceRow()
                }
            } header: {
                Text("Length").sectionLabelStyle()
            } footer: {
                Text("Ends \(draft.endDay.startDate().formatted(.dateTime.weekday(.wide).day().month(.wide)))")
                    .font(Tokens.Font.subheadline)
                    .foregroundStyle(Tokens.Colour.ink2)
            }
        }
        .sixtyListStyle()
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            if draft.name.isEmpty { nameFocused = true }
        }
    }

    /// Up to 30 days back, for a plan that's already under way, and a year ahead.
    private var startRange: ClosedRange<Date> {
        today.adding(days: -30).startDate()...today.adding(days: 365).startDate()
    }

    private var startDate: Binding<Date> {
        Binding { draft.startDay.startDate() } set: { draft.startDay = DayKey($0) }
    }
}
