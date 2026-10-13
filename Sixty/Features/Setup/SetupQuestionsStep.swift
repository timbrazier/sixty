import SwiftUI

/// Step 3: daily questions (2 to 4) and reminder times.
struct SetupQuestionsStep: View {
    @Bindable var draft: PlanDraft
    @State private var editing: PlanDraft.QuestionDraft?

    var body: some View {
        List {
            Section {
                ForEach(draft.questions) { question in
                    Button { editing = question } label: {
                        AdaptiveStack {
                            Text(question.prompt)
                                .font(Tokens.Font.body)
                                .foregroundStyle(Tokens.Colour.ink)
                            AdaptiveSpacer()
                            Text(question.summary)
                                .font(Tokens.Font.subheadline)
                                .foregroundStyle(Tokens.Colour.ink2)
                                .multilineTextAlignment(.trailing)
                        }
                        .frame(minHeight: Tokens.Size.row)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .surfaceRow()
                }
                .onDelete { draft.questions.remove(atOffsets: $0) }

                if draft.canAddQuestion {
                    AddRow(title: "Add question") {
                        editing = PlanDraft.QuestionDraft(prompt: "")
                    }
                    .surfaceRow()
                }
            } header: {
                VStack(alignment: .leading, spacing: Tokens.Space.l) {
                    SetupTitle(title: "Daily questions", lede: "Quick answers you give every day.")
                    Text("Asked every day").sectionLabelStyle()
                }
            } footer: {
                Text(questionFooter)
                    .font(Tokens.Font.subheadline)
                    .foregroundStyle(Tokens.Colour.ink2)
            }

            Section {
                ReminderRow(title: "Morning nudge", isOn: $draft.morningOn, minutes: $draft.morningMinutes)
                    .surfaceRow()
                ReminderRow(title: "Evening check-in", isOn: $draft.eveningOn, minutes: $draft.eveningMinutes)
                    .surfaceRow()
            } header: {
                Text("Reminders").sectionLabelStyle()
            } footer: {
                Text("The evening check-in is skipped on days you've already completed.")
                    .font(Tokens.Font.subheadline)
                    .foregroundStyle(Tokens.Colour.ink2)
            }
        }
        .sixtyListStyle()
        .sheet(item: $editing) { question in
            QuestionEditor(question: question) { saved in
                if let index = draft.questions.firstIndex(where: { $0.id == saved.id }) {
                    draft.questions[index] = saved
                } else {
                    draft.questions.append(saved)
                }
            }
        }
    }

    private var questionFooter: String {
        let range = PlanDraft.questionLimit
        if draft.questions.count < range.lowerBound {
            return "Add at least \(range.lowerBound) questions. Swipe left on one to delete it."
        }
        return "Keep it to \(range.lowerBound) to \(range.upperBound). Swipe left on one to delete it. Optional questions don't count against a complete day."
    }
}

/// Sheet for adding or editing a question: prompt, answer type, unit.
struct QuestionEditor: View {
    @State private var question: PlanDraft.QuestionDraft
    private let isNew: Bool
    /// Existing questions keep their answer type, so past answers still make sense.
    private let allowsKindChange: Bool
    let onSave: (PlanDraft.QuestionDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var promptFocused: Bool

    init(question: PlanDraft.QuestionDraft, allowsKindChange: Bool = true,
         onSave: @escaping (PlanDraft.QuestionDraft) -> Void) {
        _question = State(initialValue: question)
        isNew = question.prompt.isEmpty
        self.allowsKindChange = allowsKindChange
        self.onSave = onSave
    }
    private var canSave: Bool { !question.prompt.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Question, e.g. Sleep", text: $question.prompt)
                        .focused($promptFocused)
                    Picker("Answer", selection: $question.kind) {
                        Text("Number").tag(Question.Kind.number)
                        Text("Scale 1–5").tag(Question.Kind.scale)
                        Text("Text").tag(Question.Kind.text)
                    }
                    .disabled(!allowsKindChange)
                }
                .surfaceRow()

                if question.kind == .number {
                    Section {
                        TextField("Unit, e.g. hours or kg", text: $question.unit)
                        Picker("Steps of", selection: $question.step) {
                            Text("0.1").tag(0.1)
                            Text("0.5").tag(0.5)
                            Text("1").tag(1.0)
                        }
                    }
                    .surfaceRow()
                }

                Section {
                    Toggle("Optional", isOn: $question.isOptional)
                        .tint(Tokens.Colour.accent)
                } footer: {
                    Text("A day can be complete without answering an optional question.")
                }
                .surfaceRow()
            }
            .sixtyListStyle()
            .navigationTitle(isNew ? "New question" : "Edit question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(question)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear { if isNew { promptFocused = true } }
        }
        .presentationDetents([.medium, .large])
    }
}
