import SwiftUI
import SwiftData
import SixtyCore

/// Three-step plan setup: basics, activities, then questions and reminders.
/// Nothing is saved until "Start plan"; notification permission is asked for
/// after that, not on first launch.
struct PlanSetupView: View {
    /// Shown as "Cancel" on step 1 when there's somewhere to go back to.
    var onCancel: (() -> Void)?
    var onFinish: ((Plan) -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.today) private var today
    @State private var draft: PlanDraft?
    @State private var step = 1
    @State private var saveError: String?

    private let stepCount = 3

    var body: some View {
        VStack(spacing: 0) {
            header
            if let draft {
                Group {
                    switch step {
                    case 1: SetupBasicsStep(draft: draft)
                    case 2: SetupActivitiesStep(draft: draft)
                    default: SetupQuestionsStep(draft: draft)
                    }
                }
                .frame(maxHeight: .infinity)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                .id(step)

                BottomActionBar(isEnabled: canContinue(draft), action: advance) {
                    Text(step == stepCount ? "Start plan" : "Continue")
                }
            }
        }
        .background(Tokens.Colour.bg)
        .onAppear {
            if draft == nil { draft = PlanDraft(today: today) }
        }
        .alert("Couldn't save the plan", isPresented: Binding(get: { saveError != nil },
                                                               set: { if !$0 { saveError = nil } })) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: Header: "Back   Step 2 of 3", then three progress bars

    private var header: some View {
        VStack(spacing: Tokens.Space.s) {
            ZStack {
                Text("Step \(step) of \(stepCount)")
                    .font(Tokens.Font.subheadline.weight(.semibold))
                    .foregroundStyle(Tokens.Colour.ink2)
                HStack {
                    if step > 1 {
                        Button("Back") { withAnimation { step -= 1 } }
                    } else if let onCancel {
                        Button("Cancel", action: onCancel)
                    }
                    Spacer()
                }
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Colour.ink2)
            }
            .frame(minHeight: Tokens.Size.minHit)

            HStack(spacing: Tokens.Space.xxs) {
                ForEach(1...stepCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Tokens.Colour.accent : Tokens.Colour.line)
                        .frame(height: 3)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.bottom, Tokens.Space.xs)
    }

    // MARK: Actions

    private func canContinue(_ draft: PlanDraft) -> Bool {
        switch step {
        case 1: draft.canContinueFromBasics
        case 2: draft.canContinueFromActivities
        default: draft.canStart
        }
    }

    private func advance() {
        guard let draft else { return }
        if step < stepCount {
            withAnimation { step += 1 }
            return
        }
        do {
            let plan = try draft.save(in: context)
            if plan.morningReminderMinutes != nil || plan.eveningReminderMinutes != nil {
                Task {
                    await NotificationScheduler.requestPermission()
                    NotificationScheduler.reschedule(in: context)
                }
            }
            onFinish?(plan)
        } catch {
            saveError = error.localizedDescription
        }
    }
}

/// Large title and lede at the top of each setup step, as a list header.
struct SetupTitle: View {
    let title: String
    let lede: String

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text(title)
                .font(Tokens.Font.largeTitle)
                .foregroundStyle(Tokens.Colour.ink)
            Text(lede)
                .font(Tokens.Font.subheadline)
                .foregroundStyle(Tokens.Colour.ink2)
        }
        .textCase(nil)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Tokens.Space.s)
    }
}

#Preview("Setup") {
    PlanSetupView()
        .environment(\.today, PreviewData.today)
        .modelContainer(PreviewData.emptyContainer)
}
