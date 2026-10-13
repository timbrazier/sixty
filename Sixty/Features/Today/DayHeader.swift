import SwiftUI

/// Top bar: round back/forward buttons either side of the title and the
/// save status ("Today / ✓ Saved · 06:58").
struct DayHeader: View {
    let title: String
    let subtitle: String
    let isSaving: Bool
    let isSaved: Bool
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            arrow("chevron.left", label: "Previous day", action: onPrevious)
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Text(title)
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Colour.ink)
                    .contentTransition(.opacity)
                HStack(spacing: Tokens.Space.xxs) {
                    if isSaving {
                        Circle().fill(Tokens.Colour.ink3).frame(width: 5, height: 5)
                    } else if isSaved {
                        Image(systemName: "checkmark").font(.caption2.weight(.semibold))
                    }
                    Text(subtitle)
                }
                .font(Tokens.Font.footnoteRegular)
                .foregroundStyle(Tokens.Colour.ink2)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            arrow("chevron.right", label: "Next day", action: onNext)
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.xs)
        .background(Tokens.Colour.bg)
    }

    private func arrow(_ symbol: String, label: String, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(action == nil ? Tokens.Colour.ink3 : Tokens.Colour.ink)
                .frame(width: 36, height: 36)
                .background(action == nil ? Color.clear : Tokens.Colour.surface, in: Circle())
                .frame(width: Tokens.Size.minHit, height: Tokens.Size.minHit)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityLabel(label)
    }
}
