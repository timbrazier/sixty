import SwiftUI

/// Step 2: the activities ticked off each day, in two groups: the
/// non-negotiables, which every day needs, and bonus habits, which are
/// tracked but don't hold a day back. Always in edit mode, so the delete
/// minus and reorder handles show as in the design.
struct SetupActivitiesStep: View {
    @Bindable var draft: PlanDraft
    @State private var editing: PlanDraft.ActivityDraft?

    var body: some View {
        List {
            Section {
                rows(draft.coreActivities, bonus: false)
                AddRow(title: "Add non-negotiable") {
                    editing = PlanDraft.ActivityDraft(title: "")
                }
                .surfaceRow()
            } header: {
                VStack(alignment: .leading, spacing: Tokens.Space.l) {
                    SetupTitle(title: "Activities", lede: "What you tick off each day. Drag to reorder.")
                    Text(Activity.Group.core).sectionLabelStyle()
                }
            } footer: {
                Text(draft.coreActivities.isEmpty
                     ? "Add at least one. These are what make a day count."
                     : "Every one of these makes a day count.")
                    .font(Tokens.Font.subheadline)
                    .foregroundStyle(Tokens.Colour.ink2)
            }

            Section {
                rows(draft.bonusActivities, bonus: true)
                AddRow(title: "Add bonus habit") {
                    editing = PlanDraft.ActivityDraft(title: "", isBonus: true)
                }
                .surfaceRow()
            } header: {
                Text(Activity.Group.bonus).sectionLabelStyle()
            } footer: {
                Text("Tracked and exported, but a day still counts without them. Tap a row to rename it, add a target or move it between groups.")
                    .font(Tokens.Font.subheadline)
                    .foregroundStyle(Tokens.Colour.ink2)
            }
        }
        .sixtyListStyle()
        .environment(\.editMode, .constant(.active))
        .sheet(item: $editing) { activity in
            ActivityEditor(activity: activity,
                           canChangeGroup: !(draft.coreActivities.count == 1 && !activity.isBonus
                                             && draft.coreActivities.first?.id == activity.id),
                           onSave: draft.saveActivity)
        }
    }

    private func rows(_ activities: [PlanDraft.ActivityDraft], bonus: Bool) -> some View {
        ForEach(activities) { activity in
            Button { editing = activity } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.title)
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Colour.ink)
                    if !activity.target.isEmpty {
                        Text(activity.target)
                            .font(Tokens.Font.subheadline)
                            .foregroundStyle(Tokens.Colour.ink2)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: Tokens.Size.row, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Rename, add a target or move between groups")
            .surfaceRow()
        }
        .onDelete { draft.removeActivities(bonus: bonus, at: $0) }
        .onMove { draft.moveActivities(bonus: bonus, from: $0, to: $1) }
    }
}

/// Sheet for adding or editing one activity: title, optional target, and
/// whether it's a non-negotiable or a bonus habit.
struct ActivityEditor: View {
    @State private var activity: PlanDraft.ActivityDraft
    private let isNew: Bool
    /// False for the last non-negotiable, which can't become a bonus habit.
    private let canChangeGroup: Bool
    let onSave: (PlanDraft.ActivityDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool

    init(activity: PlanDraft.ActivityDraft, canChangeGroup: Bool = true,
         onSave: @escaping (PlanDraft.ActivityDraft) -> Void) {
        _activity = State(initialValue: activity)
        isNew = activity.title.isEmpty
        self.canChangeGroup = canChangeGroup
        self.onSave = onSave
    }

    private var canSave: Bool { !activity.title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title, e.g. Morning run", text: $activity.title)
                        .focused($titleFocused)
                        .submitLabel(.next)
                    TextField("Target, e.g. 5 km (optional)", text: $activity.target)
                        .submitLabel(.done)
                        .onSubmit(save)
                }
                .surfaceRow()

                Section {
                    Picker("Group", selection: $activity.isBonus) {
                        Text(Activity.Group.core).tag(false)
                        Text(Activity.Group.bonus).tag(true)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .disabled(!canChangeGroup)
                } footer: {
                    Text(canChangeGroup
                         ? "Non-negotiables make a day count. Bonus habits are tracked but optional."
                         : "You need at least one non-negotiable.")
                }
                .surfaceRow()
            }
            .sixtyListStyle()
            .navigationTitle(isNew ? "New activity" : "Edit activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onAppear { if isNew { titleFocused = true } }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard canSave else { return }
        onSave(activity)
        dismiss()
    }
}
