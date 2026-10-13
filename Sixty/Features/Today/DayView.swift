import SwiftUI
import SwiftData
import UIKit
import SixtyCore

/// One day's log: bib with ring, activities checklist, photo slot, questions
/// and note. Every edit goes through `edit(_:)`, which creates the entry on
/// first use and hands off to the auto-saver.
struct DayView: View {
    let plan: Plan
    let day: DayKey
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.today) private var today
    @Environment(AutoSaver.self) private var saver
    @Query private var entries: [DayEntry]

    @State private var titleCollapsed = false
    /// On a day that was already complete when opened, photo, questions and
    /// note fold into chips under the checklist until tapped.
    @State private var folded: Set<Fold> = []
    @State private var lastAnswers: [UUID: String] = [:]

    enum Fold: Hashable { case photo, questions, note }

    init(plan: Plan, day: DayKey, onPrevious: (() -> Void)? = nil, onNext: (() -> Void)? = nil) {
        self.plan = plan
        self.day = day
        self.onPrevious = onPrevious
        self.onNext = onNext
        let raw = day.rawValue
        _entries = Query(filter: #Predicate<DayEntry> { $0.dayKey == raw })
    }

    private var entry: DayEntry? { entries.first }
    private var isLocked: Bool { day > today }
    private var dayNumber: Int { plan.calendar.dayNumber(for: day) }

    /// The day's own snapshot once it has an entry, otherwise the plan as it is now.
    private var activities: [Activity] {
        guard let entry else { return plan.activeActivities }
        return entry.plannedActivityIDs.compactMap(plan.activity(id:))
    }

    private var questions: [Question] {
        guard let entry else { return plan.activeQuestions }
        return entry.plannedQuestionIDs.compactMap(plan.question(id:))
    }

    private var progress: DayProgress {
        entry?.progress ?? DayProgress(plannedActivityIDs: activities.map(\.id),
                                       completedActivityIDs: [],
                                       requiredQuestionIDs: questions.filter { !$0.isOptional }.map(\.id),
                                       answeredQuestionIDs: [])
    }

    var body: some View {
        VStack(spacing: 0) {
            DayHeader(title: title, subtitle: subtitle, isSaving: saver.state == .saving && entry != nil,
                      isSaved: entry != nil, onPrevious: onPrevious, onNext: onNext)

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                    BibCard(label: day == plan.calendar.endDay && progress.isComplete ? "Plan complete" : plan.name,
                            dayNumber: dayNumber, length: plan.lengthDays, date: day.longName,
                            done: progress.activitiesDone, total: progress.activitiesTotal,
                            isComplete: progress.isComplete, isLocked: isLocked)
                        .onGeometryChange(for: Bool.self) { proxy in
                            proxy.frame(in: .scrollView).maxY < 0
                        } action: { collapsed in
                            withAnimation(.easeOut(duration: 0.2)) { titleCollapsed = collapsed }
                        }

                    if progress.isComplete {
                        DayCompleteBanner(dayNumber: dayNumber, detail: completeDetail)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    checklist
                    if !folded.isEmpty { foldedChips }
                    sections
                }
                .padding(.horizontal, Tokens.Space.m)
                .padding(.vertical, Tokens.Space.s)
                .animation(Tokens.Motion.ring, value: progress.isComplete)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Tokens.Colour.bg)
        .sensoryFeedback(.impact(weight: .light), trigger: progress.activitiesDone) { old, new in new > old }
        .sensoryFeedback(.success, trigger: progress.isComplete) { _, new in new }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
            }
        }
        .onAppear {
            if progress.isComplete { folded = [.photo, .questions, .note] }
            loadLastAnswers()
        }
    }

    // MARK: Sections

    private var checklist: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            SectionHeader("Activities", trailing: "\(progress.activitiesDone) of \(progress.activitiesTotal)")
            Card {
                ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                    if index > 0 { CardDivider(leading: 58) }
                    ActivityRow(title: activity.title, target: activity.target,
                                isDone: progress.completedActivityIDs.contains(activity.id),
                                isLocked: isLocked) {
                        toggle(activity.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var sections: some View {
        if !folded.contains(.photo) {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                SectionHeader("Photo")
                PhotoSlot(isLocked: isLocked)
            }
        }
        if !folded.contains(.questions) && !questions.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                SectionHeader("Questions", trailing: "\(progress.questionsAnswered) of \(progress.questionsTotal)")
                Card {
                    ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                        if index > 0 { CardDivider() }
                        QuestionRow(question: question,
                                    answer: answerBinding(question.id),
                                    suggestion: lastAnswers[question.id],
                                    isLocked: isLocked)
                    }
                }
            }
        }
        if !folded.contains(.note) {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                SectionHeader("Note")
                NoteField(text: journalBinding, isLocked: isLocked)
            }
        }
    }

    /// "Photo ✓  Questions 3/3  Note ✓" under a completed day's checklist.
    private var foldedChips: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.xs) { chips }
            VStack(alignment: .leading, spacing: Tokens.Space.xs) { chips }
        }
    }

    @ViewBuilder
    private var chips: some View {
        if folded.contains(.photo) {
            FoldChip(title: "Photo", isDone: entry?.photoFilename != nil) { unfold(.photo) }
        }
        if folded.contains(.questions) && !questions.isEmpty {
            FoldChip(title: "Questions \(answeredCount)/\(questions.count)", isDone: nil) { unfold(.questions) }
        }
        if folded.contains(.note) {
            FoldChip(title: "Note", isDone: !(entry?.journal.isEmpty ?? true)) { unfold(.note) }
        }
    }

    /// All answered questions, optional ones included, for the chip.
    private var answeredCount: Int {
        questions.filter { !(entry?.answer(for: $0.id).isEmpty ?? true) }.count
    }

    private func unfold(_ fold: Fold) {
        withAnimation(.snappy) { _ = folded.remove(fold) }
    }

    // MARK: Header text

    private var title: String {
        if titleCollapsed { return "Day \(dayNumber) · \(progress.activitiesDone) of \(progress.activitiesTotal)" }
        if day == plan.calendar.endDay { return "Final day" }
        return day == today ? "Today" : day.shortName
    }

    private var subtitle: String {
        if isLocked { return "Locked" }
        guard let entry else { return "Nothing logged yet" }
        if saver.state == .saving { return "Saving…" }
        if saver.state == .failed { return "Couldn't save" }
        let time = entry.updatedAt.formatted(date: .omitted, time: .shortened)
        return day == today ? "Saved · \(time)" : "Past day · Saved"
    }

    /// "Logged in 1:48 · Day 15 opens tomorrow"
    private var completeDetail: String {
        var parts: [String] = []
        if let start = entry?.firstEditedAt, let end = entry?.completedAt {
            let seconds = Int(end.timeIntervalSince(start))
            // Only worth showing for a single sitting.
            if seconds >= 0 && seconds < 30 * 60 {
                parts.append("Logged in \(seconds / 60):\(String(format: "%02d", seconds % 60))")
            }
        }
        if day == plan.calendar.endDay {
            parts.append("Plan complete")
        } else if day == today {
            parts.append("Day \(dayNumber + 1) opens tomorrow")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Editing

    /// Applies a change to the day's entry, creating it if needed, then
    /// stamps the timings and queues an auto-save.
    private func edit(_ change: (DayEntry) -> Void) {
        guard !isLocked else { return }
        let entry = EntryStore(context: context).entryForEditing(day, plan: plan)
        let wasComplete = entry.isComplete
        change(entry)
        let now = Date()
        if entry.firstEditedAt == nil { entry.firstEditedAt = now }
        entry.updatedAt = now
        if entry.isComplete {
            if !wasComplete { entry.completedAt = now }
        } else {
            entry.completedAt = nil
        }
        saver.changed()
    }

    private func toggle(_ activityID: UUID) {
        withAnimation(Tokens.Motion.ring) {
            edit { entry in
                if let index = entry.completedActivityIDs.firstIndex(of: activityID) {
                    entry.completedActivityIDs.remove(at: index)
                } else {
                    entry.completedActivityIDs.append(activityID)
                }
            }
        }
    }

    private func answerBinding(_ questionID: UUID) -> Binding<String> {
        Binding {
            entry?.answer(for: questionID) ?? ""
        } set: { newValue in
            withAnimation(Tokens.Motion.ring) {
                edit { entry in
                    if newValue.isEmpty {
                        entry.answers.removeValue(forKey: questionID.uuidString)
                    } else {
                        entry.answers[questionID.uuidString] = newValue
                    }
                }
            }
        }
    }

    private var journalBinding: Binding<String> {
        Binding {
            entry?.journal ?? ""
        } set: { newValue in
            edit { $0.journal = newValue }
        }
    }

    /// The most recent earlier answer to each question, so "Add" on Sleep or
    /// Weight starts from last time's number rather than zero.
    private func loadLastAnswers() {
        let raw = day.rawValue
        var descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate { $0.dayKey != raw },
                                                   sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 30
        let earlier = ((try? context.fetch(descriptor)) ?? []).filter { $0.day < day }
        var found: [UUID: String] = [:]
        for question in questions {
            if let answer = earlier.lazy.map({ $0.answer(for: question.id) }).first(where: { !$0.isEmpty }) {
                found[question.id] = answer
            }
        }
        lastAnswers = found
    }
}

func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

#Preview("Day 14, partial") {
    PreviewHost { plan in DayView(plan: plan, day: PreviewData.today) }
}

#Preview("Day 13, complete") {
    PreviewHost { plan in DayView(plan: plan, day: PreviewData.today.adding(days: -1)) }
}

#Preview("Day 15, locked") {
    PreviewHost { plan in DayView(plan: plan, day: PreviewData.today.adding(days: 1)) }
}
