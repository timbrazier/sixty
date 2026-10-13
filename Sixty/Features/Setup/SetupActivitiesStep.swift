import SwiftUI

/// Step 2: the activities ticked off each day. Always in edit mode, so the
/// delete minus and reorder handles show as in the design.
struct SetupActivitiesStep: View {
    @Bindable var draft: PlanDraft
    @State private var editing: PlanDraft.ActivityDraft?

    var body: some View {
        List {
            Section {
                ForEach(draft.activities) { activity in
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
                    .accessibilityHint("Rename or add a target")
                    .surfaceRow()
                }
                .onDelete { draft.activities.remove(atOffsets: $0) }
                .onMove { draft.activities.move(fromOffsets: $0, toOffset: $1) }

                AddRow(title: "Add activity") {
                    editing = PlanDraft.ActivityDraft(title: "")
                }
                .surfaceRow()
            } header: {
                SetupTitle(title: "Activities", lede: "What you tick off each day. Drag to reorder.")
            } footer: {
                Text(draft.activities.isEmpty
                     ? "Add at least one activity."
                     : "Tap a row to rename it or add a target. Tap the minus to delete.")
                    .font(Tokens.Font.subheadline)
                    .foregroundStyle(Tokens.Colour.ink2)
            }
        }
        .sixtyListStyle()
        .environment(\.editMode, .constant(.active))
        .sheet(item: $editing) { activity in
            ActivityEditor(activity: activity) { saved in
                if let index = draft.activities.firstIndex(where: { $0.id == saved.id }) {
                    draft.activities[index] = saved
                } else {
                    draft.activities.append(saved)
                }
            }
        }
    }
}

/// Sheet for adding or editing one activity: title and optional target.
struct ActivityEditor: View {
    @State private var activity: PlanDraft.ActivityDraft
    private let isNew: Bool
    let onSave: (PlanDraft.ActivityDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool

    init(activity: PlanDraft.ActivityDraft, onSave: @escaping (PlanDraft.ActivityDraft) -> Void) {
        _activity = State(initialValue: activity)
        isNew = activity.title.isEmpty
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
            .onAppear { titleFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard canSave else { return }
        onSave(activity)
        dismiss()
    }
}
