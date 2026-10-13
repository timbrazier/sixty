import SwiftUI
import SwiftData
import SixtyCore

/// Settings → Activities. Removing an activity archives it, so past days
/// keep it; today and future days pick up the new list.
struct ActivitiesEditor: View {
    let plan: Plan
    @Environment(\.modelContext) private var context
    @Environment(\.today) private var today
    @Environment(AutoSaver.self) private var saver
    @State private var editing: PlanDraft.ActivityDraft?

    var body: some View {
        List {
            Section {
                ForEach(plan.activeActivities) { activity in
                    Button {
                        editing = .init(id: activity.id, title: activity.title, target: activity.target ?? "")
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.title).foregroundStyle(Tokens.Colour.ink)
                            if let target = activity.target {
                                Text(target)
                                    .font(Tokens.Font.subheadline)
                                    .foregroundStyle(Tokens.Colour.ink2)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: Tokens.Size.row, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .surfaceRow()
                }
                .onDelete(perform: archive)
                .onMove(perform: move)
                .deleteDisabled(plan.activeActivities.count <= 1)

                AddRow(title: "Add activity") { editing = PlanDraft.ActivityDraft(title: "") }
                    .surfaceRow()
            } footer: {
                Text("Removing an activity keeps it on the days it was part of. Today and future days use this list.")
                    .font(Tokens.Font.footnoteRegular)
            }
        }
        .sixtyListStyle()
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Activities")
        .sheet(item: $editing) { draft in
            ActivityEditor(activity: draft, onSave: save)
        }
    }

    private func save(_ draft: PlanDraft.ActivityDraft) {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = draft.target.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = plan.activity(id: draft.id) {
            existing.title = title
            existing.target = target.isEmpty ? nil : target
        } else {
            let order = (plan.activities.map(\.sortOrder).max() ?? -1) + 1
            plan.activities.append(Activity(id: draft.id, title: title, target: target.isEmpty ? nil : target, sortOrder: order))
        }
        changed()
    }

    private func archive(_ offsets: IndexSet) {
        let active = plan.activeActivities
        for index in offsets { active[index].isArchived = true }
        changed()
    }

    private func move(_ offsets: IndexSet, _ destination: Int) {
        var active = plan.activeActivities
        active.move(fromOffsets: offsets, toOffset: destination)
        for (index, activity) in active.enumerated() { activity.sortOrder = index }
        changed()
    }

    private func changed() {
        EntryStore(context: context).refreshSnapshots(for: plan, today: today)
        saver.changed()
    }
}

/// Settings → Daily questions: 2 to 4, archived rather than deleted.
struct QuestionsEditor: View {
    let plan: Plan
    @Environment(\.modelContext) private var context
    @Environment(\.today) private var today
    @Environment(AutoSaver.self) private var saver
    @State private var editing: PlanDraft.QuestionDraft?

    var body: some View {
        let active = plan.activeQuestions
        List {
            Section {
                ForEach(active) { question in
                    Button {
                        editing = .init(id: question.id, prompt: question.prompt, kind: question.kind,
                                        unit: question.unit ?? "", step: question.step, isOptional: question.isOptional)
                    } label: {
                        AdaptiveStack {
                            Text(question.prompt).foregroundStyle(Tokens.Colour.ink)
                            AdaptiveSpacer()
                            Text(question.summary)
                                .font(Tokens.Font.subheadline)
                                .foregroundStyle(Tokens.Colour.ink2)
                        }
                        .frame(minHeight: Tokens.Size.row)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .surfaceRow()
                }
                .onDelete(perform: archive)
                .onMove(perform: move)
                .deleteDisabled(active.count <= PlanDraft.questionLimit.lowerBound)

                if active.count < PlanDraft.questionLimit.upperBound {
                    AddRow(title: "Add question") { editing = PlanDraft.QuestionDraft(prompt: "") }
                        .surfaceRow()
                }
            } footer: {
                Text("Keep it to 2 to 4. Removed questions keep their answers on past days.")
                    .font(Tokens.Font.footnoteRegular)
            }
        }
        .sixtyListStyle()
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Daily questions")
        .sheet(item: $editing) { draft in
            QuestionEditor(question: draft, allowsKindChange: plan.question(id: draft.id) == nil, onSave: save)
        }
    }

    private func save(_ draft: PlanDraft.QuestionDraft) {
        let prompt = draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let unit = draft.unit.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = plan.question(id: draft.id) {
            existing.prompt = prompt
            existing.unit = unit.isEmpty ? nil : unit
            existing.step = draft.step
            existing.isOptional = draft.isOptional
        } else {
            let order = (plan.questions.map(\.sortOrder).max() ?? -1) + 1
            plan.questions.append(Question(id: draft.id, prompt: prompt, kind: draft.kind,
                                           unit: unit.isEmpty ? nil : unit, step: draft.step,
                                           isOptional: draft.isOptional, sortOrder: order))
        }
        changed()
    }

    private func archive(_ offsets: IndexSet) {
        let active = plan.activeQuestions
        for index in offsets { active[index].isArchived = true }
        changed()
    }

    private func move(_ offsets: IndexSet, _ destination: Int) {
        var active = plan.activeQuestions
        active.move(fromOffsets: offsets, toOffset: destination)
        for (index, question) in active.enumerated() { question.sortOrder = index }
        changed()
    }

    private func changed() {
        EntryStore(context: context).refreshSnapshots(for: plan, today: today)
        saver.changed()
    }
}

/// Settings → Dates: start day and length.
struct DatesEditor: View {
    @Bindable var plan: Plan
    @Environment(AutoSaver.self) private var saver
    @State private var length: PlanDraft.Length = .days60
    @State private var customDays = 45

    var body: some View {
        List {
            Section {
                DatePicker("Starts", selection: startDate, displayedComponents: .date)
                    .frame(minHeight: Tokens.Size.row)
                    .surfaceRow()
            } footer: {
                Text("Moving the start changes which day number each date is. Logged days keep their dates.")
                    .font(Tokens.Font.footnoteRegular)
            }

            Section {
                SegmentedChoice(selection: $length, options: [
                    .init(value: .days30, label: "30", selectedLabel: "30 days"),
                    .init(value: .days60, label: "60", selectedLabel: "60 days"),
                    .init(value: .days90, label: "90", selectedLabel: "90 days"),
                    .init(value: .custom, label: "Custom"),
                ])
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if length == .custom {
                    Stepper(value: $customDays, in: 7...365) {
                        HStack {
                            Text("Days")
                            Spacer()
                            Text("\(customDays)").monospacedDigit().foregroundStyle(Tokens.Colour.ink2)
                        }
                    }
                    .frame(minHeight: Tokens.Size.row)
                    .surfaceRow()
                }
            } header: {
                Text("Length").sectionLabelStyle()
            } footer: {
                Text("Ends \(plan.calendar.endDay.longName)")
                    .font(Tokens.Font.footnoteRegular)
            }
        }
        .sixtyListStyle()
        .navigationTitle("Dates")
        .onAppear {
            switch plan.lengthDays {
            case 30: length = .days30
            case 60: length = .days60
            case 90: length = .days90
            default:
                length = .custom
                customDays = plan.lengthDays
            }
        }
        .onChange(of: length) { _, _ in applyLength() }
        .onChange(of: customDays) { _, _ in applyLength() }
    }

    private var startDate: Binding<Date> {
        Binding { plan.startDay.startDate() } set: {
            plan.startDay = DayKey($0)
            saver.changed()
        }
    }

    private func applyLength() {
        let days = length.presetDays ?? customDays
        guard days != plan.lengthDays else { return }
        plan.lengthDays = days
        saver.changed()
    }
}
