import SwiftUI
import SwiftData
import UIKit
import SixtyCore

/// One day's log: bib with ring, activities checklist, photo slot, questions
/// and note. Every edit goes through `edit(_:)`, which creates the entry on
/// first use and hands off to the auto-saver.
///
/// Past days are editable, with an "Editing a past day" banner. Future days
/// are read-only. Swipe on the bib, or use the arrows, to move a day; tap
/// the title for the 7-day strip.
struct DayView: View {
    let plan: Plan
    let day: DayKey
    @Binding var isStripOpen: Bool
    let onSelect: (DayKey) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.today) private var today
    @Environment(AutoSaver.self) private var saver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var entries: [DayEntry]

    @State private var titleCollapsed = false
    /// On a day that was already complete when opened, photo, questions and
    /// note fold into chips under the checklist until tapped.
    @State private var folded: Set<Fold> = []
    @State private var lastAnswers: [UUID: String] = [:]
    @State private var ghostFilename: String?
    @State private var photoFailed = false

    // Swipe between days
    @State private var dragX: CGFloat = 0
    @State private var pageWidth: CGFloat = 390
    @State private var blockedBounces = 0

    enum Fold: Hashable { case photo, questions, note }

    init(plan: Plan, day: DayKey, isStripOpen: Binding<Bool>, onSelect: @escaping (DayKey) -> Void) {
        self.plan = plan
        self.day = day
        _isStripOpen = isStripOpen
        self.onSelect = onSelect
        let raw = day.rawValue
        _entries = Query(filter: #Predicate<DayEntry> { $0.dayKey == raw })
    }

    private var entry: DayEntry? { entries.first }
    private var isLocked: Bool { day > today }
    private var dayNumber: Int { plan.calendar.dayNumber(for: day) }
    /// Today, or the last day once the plan has finished.
    private var currentDay: DayKey { min(today, plan.calendar.endDay) }
    private var isPastDay: Bool { day < currentDay }
    private var canGoBack: Bool { day > plan.calendar.startDay }
    /// Arrows and swipes stop at today; the strip can still open future days.
    private var canGoForward: Bool { day < currentDay }

    /// The day's own snapshot once it has an entry, otherwise the plan as it is now.
    private var activities: [Activity] {
        guard let entry else { return plan.activeActivities }
        return entry.plannedActivityIDs.compactMap(plan.activity(id:))
    }

    /// Which activities were bonus habits on this day.
    private var bonusIDs: Set<UUID> {
        guard let entry else { return Set(plan.bonusActivities.map(\.id)) }
        return Set(entry.bonusActivityIDs)
    }

    /// Photos are asked for on Day 1 and every 10th day. A day that already
    /// has a photo keeps showing it.
    private var showsPhoto: Bool {
        plan.calendar.isPhotoDay(day) || entry?.photoFilename != nil
    }

    private var coreActivities: [Activity] { activities.filter { !bonusIDs.contains($0.id) } }
    private var bonusActivities: [Activity] { activities.filter { bonusIDs.contains($0.id) } }

    private var questions: [Question] {
        guard let entry else { return plan.activeQuestions }
        return entry.plannedQuestionIDs.compactMap(plan.question(id:))
    }

    private var progress: DayProgress {
        entry?.progress ?? DayProgress(plannedActivityIDs: coreActivities.map(\.id),
                                       completedActivityIDs: [],
                                       requiredQuestionIDs: questions.filter { !$0.isOptional }.map(\.id),
                                       answeredQuestionIDs: [],
                                       bonusActivityIDs: bonusActivities.map(\.id))
    }

    private var bibLabel: String {
        if day == plan.calendar.endDay && progress.isComplete { return "Plan complete" }
        if isPastDay { return "Editing" }
        return plan.name
    }

    var body: some View {
        VStack(spacing: 0) {
            DayHeader(title: title, subtitle: subtitle, isSaving: saver.state == .saving && entry != nil,
                      isSaved: entry != nil && !isLocked,
                      onPrevious: canGoBack ? { onSelect(day.adding(days: -1)) } : nil,
                      onNext: canGoForward ? { onSelect(day.adding(days: 1)) } : nil,
                      onTitleTap: { withAnimation(.snappy) { isStripOpen.toggle() } })

            if isStripOpen {
                DayStrip(plan: plan, selected: day, onSelect: onSelect)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                    BibCard(label: bibLabel,
                            dayNumber: dayNumber, length: plan.lengthDays, date: day.longName,
                            done: progress.activitiesDone, total: progress.activitiesTotal,
                            isComplete: progress.isComplete, isLocked: isLocked)
                        .onGeometryChange(for: Bool.self) { proxy in
                            proxy.frame(in: .scrollView).maxY < 0
                        } action: { collapsed in
                            withAnimation(.easeOut(duration: 0.2)) { titleCollapsed = collapsed }
                        }
                        .simultaneousGesture(swipe)

                    if isLocked {
                        lockedNotice
                        checklist
                    } else {
                        if isPastDay {
                            PastDayBanner { onSelect(currentDay) }
                        }
                        if progress.isComplete && day == plan.calendar.endDay {
                            FinalSummary(plan: plan)
                                .transition(.opacity)
                        } else if progress.isComplete {
                            DayCompleteBanner(dayNumber: dayNumber, detail: completeDetail)
                                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        }
                        checklist
                        if !folded.isEmpty { foldedChips }
                        sections
                    }
                }
                .padding(.horizontal, Tokens.Space.m)
                .padding(.vertical, Tokens.Space.s)
                .offset(x: dragX)
                .animation(Tokens.Motion.ring, value: progress.isComplete)
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay(alignment: dragX < 0 ? .trailing : .leading) { dragLock }
        }
        .background(Tokens.Colour.bg)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pageWidth = $0 }
        .sensoryFeedback(.impact(weight: .light), trigger: progress.activitiesDone + progress.bonusDone) { old, new in new > old }
        .sensoryFeedback(.success, trigger: progress.isComplete) { _, new in new }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: blockedBounces)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
            }
        }
        .onAppear {
            if progress.isComplete { folded = showsPhoto ? [.photo, .questions, .note] : [.questions, .note] }
            loadLastAnswers()
            loadGhost()
        }
        .alert("Couldn't save the photo", isPresented: $photoFailed) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: Swiping

    /// Swipe left for the next day, right for the previous one. Where there's
    /// nowhere to go (a future day, or past Day 1 or the last day) the page
    /// moves about 30% and springs back with a rigid haptic.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                let dx = value.translation.width
                guard abs(dx) > abs(value.translation.height) else { return }
                if isBlocked(dx) {
                    let limit = pageWidth * 0.3
                    dragX = limit * tanh(dx / limit)
                } else {
                    dragX = dx
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                if abs(dx) > 80 && abs(dx) > abs(value.translation.height) && !isBlocked(dx) {
                    onSelect(day.adding(days: dx < 0 ? 1 : -1))
                } else {
                    if isBlocked(dx) && abs(dx) > 40 { blockedBounces += 1 }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { dragX = 0 }
                }
            }
    }

    private func isBlocked(_ dx: CGFloat) -> Bool {
        dx < 0 ? !canGoForward : !canGoBack
    }

    /// The lock that shows while pulling towards tomorrow.
    @ViewBuilder
    private var dragLock: some View {
        if dragX < -20 && !canGoForward && day == today && day < plan.calendar.endDay {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(Tokens.Colour.ink3)
                .frame(width: 56, height: 56)
                .background(Tokens.Colour.surface2, in: Circle())
                .padding(.trailing, Tokens.Space.m)
                .opacity(min(1, Double(-dragX) / 80))
                .accessibilityHidden(true)
        }
    }

    // MARK: Sections

    /// "Day 15 opens tomorrow · You can look ahead. Logging starts at midnight."
    private var lockedNotice: some View {
        let daysAway = today.days(to: day)
        return VStack(spacing: Tokens.Space.xs) {
            Text(daysAway == 1 ? "Day \(dayNumber) opens tomorrow" : "Day \(dayNumber) opens \(day.shortName)")
                .font(Tokens.Font.title3)
                .foregroundStyle(Tokens.Colour.ink)
            Text(daysAway == 1 ? "You can look ahead. Logging starts at midnight."
                               : "You can look ahead. Logging starts on the day.")
                .font(Tokens.Font.subheadline)
                .foregroundStyle(Tokens.Colour.ink2)
            Button("Back to Day \(plan.calendar.dayNumber(for: currentDay))") { onSelect(currentDay) }
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Colour.ink)
                .padding(.horizontal, Tokens.Space.xl)
                .frame(minHeight: Tokens.Size.minHit)
                .background(Tokens.Colour.surface, in: Capsule())
                .buttonStyle(.plain)
                .padding(.top, Tokens.Space.xs)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    /// Non-negotiables, then bonus habits, each with its own count.
    @ViewBuilder
    private var checklist: some View {
        activityGroup(Activity.Group.core, coreActivities,
                      done: progress.activitiesDone, total: progress.activitiesTotal)
        if !bonusActivities.isEmpty {
            activityGroup(Activity.Group.bonus, bonusActivities,
                          done: progress.bonusDone, total: progress.bonusTotal)
        }
    }

    private func activityGroup(_ title: String, _ items: [Activity], done: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            SectionHeader(title, trailing: isLocked ? nil : "\(done) of \(total)")
            Card {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, activity in
                    if index > 0 { CardDivider(leading: 58) }
                    ActivityRow(title: activity.title, target: isLocked ? nil : activity.target,
                                isDone: progress.completedActivityIDs.contains(activity.id),
                                isLocked: isLocked) {
                        toggle(activity.id)
                    }
                }
            }
            .opacity(isLocked ? 0.7 : 1)
        }
    }

    @ViewBuilder
    private var sections: some View {
        if showsPhoto && !folded.contains(.photo) {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                SectionHeader("Photo", trailing: "Day \(dayNumber)")
                PhotoSection(filename: entry?.photoFilename,
                             takenAt: entry?.photoTakenAt,
                             ghostFilename: ghostFilename,
                             isLocked: isLocked,
                             onPhoto: setPhoto,
                             onRemove: removePhoto)
            }
        }
        if !showsPhoto, let next = plan.calendar.nextPhotoDay(onOrAfter: day) {
            Label("Next photo: Day \(plan.calendar.dayNumber(for: next)) · \(next.shortName)", systemImage: "camera")
                .font(Tokens.Font.footnoteRegular)
                .foregroundStyle(Tokens.Colour.ink2)
                .padding(.horizontal, Tokens.Space.m)
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
        guard let entry else { return isPastDay ? "Past day · Nothing logged" : "Nothing logged yet" }
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
            if !wasComplete {
                entry.completedAt = now
                if day == today { NotificationScheduler.dayCompleted(day) }
            }
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

    /// Resizes and writes the photo off the main thread, then points the
    /// entry at it and removes the one it replaced.
    private func setPhoto(_ image: UIImage) {
        let day = day
        Task {
            let saved = try? await Task.detached(priority: .userInitiated) {
                try PhotoStore.save(image, day: day)
            }.value
            guard let saved else {
                photoFailed = true
                return
            }
            var replaced: String?
            withAnimation {
                edit { entry in
                    replaced = entry.photoFilename
                    entry.photoFilename = saved
                    entry.photoTakenAt = Date()
                }
            }
            // Save now so the entry never points at a deleted file.
            saver.saveNow()
            if let replaced { PhotoStore.delete(replaced) }
        }
    }

    private func removePhoto() {
        var removed: String?
        withAnimation {
            edit { entry in
                removed = entry.photoFilename
                entry.photoFilename = nil
                entry.photoTakenAt = nil
            }
        }
        saver.saveNow()
        if let removed { PhotoStore.delete(removed) }
    }

    /// Day 1's photo for the camera ghost, or the earliest photo if Day 1
    /// has none. None on Day 1 itself.
    private func loadGhost() {
        guard day > plan.calendar.startDay else { return }
        let raw = day.rawValue
        var descriptor = FetchDescriptor<DayEntry>(
            predicate: #Predicate { $0.photoFilename != nil && $0.dayKey != raw },
            sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        ghostFilename = (try? context.fetch(descriptor))?.first?.photoFilename
    }

    /// The most recent earlier answer to each question, so "Add" on a number like
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
    PreviewHost { plan in DayView(plan: plan, day: PreviewData.today, isStripOpen: .constant(false)) { _ in } }
}

#Preview("Day 12, past day") {
    PreviewHost { plan in
        DayView(plan: plan, day: PreviewData.today.adding(days: -2), isStripOpen: .constant(true)) { _ in }
    }
}

#Preview("Day 60, plan complete") {
    PreviewHost(today: PreviewData.startDay.adding(days: 59), loggedThrough: 60) { plan in
        DayView(plan: plan, day: plan.calendar.endDay, isStripOpen: .constant(false)) { _ in }
    }
}

#Preview("Day 15, locked") {
    PreviewHost { plan in
        DayView(plan: plan, day: PreviewData.today.adding(days: 1), isStripOpen: .constant(true)) { _ in }
    }
}
