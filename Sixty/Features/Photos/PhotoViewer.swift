import SwiftUI
import SixtyCore

/// Full-screen photos, swipe between days. Share the one showing, or open
/// its day on Today.
struct PhotoViewer: View {
    let plan: Plan
    /// Entries with photos, oldest first.
    let entries: [DayEntry]
    let onOpenDay: (DayKey) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var current: String

    init(plan: Plan, entries: [DayEntry], startDay: DayKey, onOpenDay: @escaping (DayKey) -> Void) {
        self.plan = plan
        self.entries = entries
        self.onOpenDay = onOpenDay
        _current = State(initialValue: startDay.rawValue)
    }

    private var currentEntry: DayEntry? { entries.first { $0.dayKey == current } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: Tokens.Size.minHit, height: Tokens.Size.minHit)
                }
                .accessibilityLabel("Close")
                Spacer()
                if let entry = currentEntry {
                    VStack(spacing: 0) {
                        Text("Day \(plan.calendar.dayNumber(for: entry.day))")
                            .font(Tokens.Font.headline)
                        Text(entry.day.longName)
                            .font(Tokens.Font.footnoteRegular)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .accessibilityElement(children: .combine)
                }
                Spacer()
                if let filename = currentEntry?.photoFilename {
                    ShareLink(item: PhotoStore.url(for: filename)) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                            .frame(width: Tokens.Size.minHit, height: Tokens.Size.minHit)
                    }
                    .accessibilityLabel("Share photo")
                } else {
                    Color.clear.frame(width: Tokens.Size.minHit, height: Tokens.Size.minHit)
                }
            }
            .padding(.horizontal, Tokens.Space.s)

            TabView(selection: $current) {
                ForEach(entries) { entry in
                    if let filename = entry.photoFilename {
                        PhotoThumbnail(filename: filename, maxPixel: 2000, contentMode: .fit)
                            .tag(entry.dayKey)
                            .accessibilityLabel("Photo for Day \(plan.calendar.dayNumber(for: entry.day))")
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if let entry = currentEntry {
                Button("Open Day \(plan.calendar.dayNumber(for: entry.day))") {
                    let day = entry.day
                    dismiss()
                    onOpenDay(day)
                }
                .font(Tokens.Font.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, Tokens.Space.xl)
                .frame(minHeight: Tokens.Size.minHit)
                .background(.white.opacity(0.15), in: Capsule())
                .padding(.vertical, Tokens.Space.m)
            }
        }
        .foregroundStyle(.white)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
