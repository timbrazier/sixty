import SwiftUI
import SwiftData
import SixtyCore

/// The Photos tab: Day 1 against the latest photo, then every day so far
/// newest first. Tap a photo to view it full screen; Select picks photos to
/// share, or two to compare.
struct PhotosScreen: View {
    let plan: Plan

    @Environment(\.today) private var today
    @Environment(AppRouter.self) private var router
    @Query(sort: \DayEntry.date) private var entries: [DayEntry]
    @AppStorage("compareMode") private var compareMode = PhotoCompare.Mode.sideBySide.rawValue

    @State private var isSelecting = false
    @State private var selection: [DayKey] = []
    /// Two days picked with Select → Compare; nil means Day 1 vs latest.
    @State private var comparePair: (DayKey, DayKey)?
    @State private var viewing: ViewerItem?

    struct ViewerItem: Identifiable {
        let day: DayKey
        var id: String { day.rawValue }
    }

    var body: some View {
        let byDay = Dictionary(entries.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        let withPhotos = entries.filter { $0.photoFilename != nil && plan.calendar.contains($0.day) }
        let days = plan.calendar.daysSoFar(today: today).reversed()

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                    comparison(byDay: byDay, withPhotos: withPhotos)

                    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                        SectionHeader("Timeline", trailing: "\(withPhotos.count) of \(days.count) days")
                        if days.isEmpty {
                            Text("Photos appear here once the plan starts.")
                                .font(Tokens.Font.subheadline)
                                .foregroundStyle(Tokens.Colour.ink2)
                                .padding(.horizontal, Tokens.Space.m)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.xs), count: 3),
                                  spacing: Tokens.Space.xs) {
                            ForEach(Array(days), id: \.self) { day in
                                tile(day: day, filename: byDay[day]?.photoFilename)
                            }
                        }
                    }
                }
                .padding(.horizontal, Tokens.Space.m)
                .padding(.bottom, Tokens.Space.xl)
            }
            .background(Tokens.Colour.bg)
            .navigationTitle("Photos")
            .toolbarBackground(Tokens.Colour.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSelecting ? "Done" : "Select") {
                        withAnimation(.snappy) {
                            isSelecting.toggle()
                            selection = []
                        }
                    }
                    .disabled(withPhotos.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSelecting { selectionBar }
            }
            .fullScreenCover(item: $viewing) { item in
                PhotoViewer(plan: plan, entries: withPhotos, startDay: item.day) { day in
                    router.open(day)
                }
            }
        }
    }

    // MARK: Comparison

    @ViewBuilder
    private func comparison(byDay: [DayKey: DayEntry], withPhotos: [DayEntry]) -> some View {
        let pair = resolvedPair(withPhotos: withPhotos)
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            HStack {
                Text(comparePair == nil ? "Day 1 vs latest" : "Comparing")
                Spacer()
                Menu {
                    Picker("View", selection: $compareMode) {
                        ForEach(PhotoCompare.Mode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    if comparePair != nil {
                        Button("Back to Day 1 vs latest") { comparePair = nil }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(mode.title)
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                    .frame(minHeight: Tokens.Size.minHit - 12)
                }
            }
            .sectionLabelStyle()
            .padding(.horizontal, Tokens.Space.m)

            PhotoCompare(left: side(pair.0, byDay), right: side(pair.1, byDay), mode: mode)
        }
    }

    private var mode: PhotoCompare.Mode {
        PhotoCompare.Mode(rawValue: compareMode) ?? .sideBySide
    }

    /// The picked pair, else Day 1 (or the first photo) against the latest photo.
    private func resolvedPair(withPhotos: [DayEntry]) -> (DayKey, DayKey) {
        if let comparePair { return comparePair }
        let first = withPhotos.first?.day ?? plan.calendar.startDay
        let latest = withPhotos.last?.day ?? min(max(today, plan.calendar.startDay), plan.calendar.endDay)
        return (first, latest)
    }

    private func side(_ day: DayKey, _ byDay: [DayKey: DayEntry]) -> PhotoCompare.Side {
        PhotoCompare.Side(dayNumber: plan.calendar.dayNumber(for: day), day: day,
                          filename: byDay[day]?.photoFilename)
    }

    // MARK: Timeline

    @ViewBuilder
    private func tile(day: DayKey, filename: String?) -> some View {
        let number = plan.calendar.dayNumber(for: day)
        let isSelected = selection.contains(day)
        ZStack(alignment: .topLeading) {
            if let filename {
                Color.clear
                    .overlay { PhotoThumbnail(filename: filename, maxPixel: 600) }
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.chip))
            } else {
                RoundedRectangle(cornerRadius: Tokens.Radius.chip)
                    .strokeBorder(Tokens.Colour.line2, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .overlay {
                        Text("No photo")
                            .font(Tokens.Font.footnoteRegular)
                            .foregroundStyle(Tokens.Colour.ink3)
                    }
            }
            Text("\(number)")
                .font(Tokens.Font.stat(14))
                .foregroundStyle(Tokens.Colour.ink)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Tokens.Colour.surface, in: RoundedRectangle(cornerRadius: 6))
                .padding(6)
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
        .overlay(alignment: .bottomTrailing) {
            if isSelecting && filename != nil {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(isSelected ? Tokens.Colour.accentInk : .white,
                                     isSelected ? Tokens.Colour.accent : .black.opacity(0.25))
                    .padding(6)
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .opacity(isSelecting && filename == nil ? 0.4 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            guard filename != nil else { return }
            if isSelecting {
                if let index = selection.firstIndex(of: day) {
                    selection.remove(at: index)
                } else {
                    selection.append(day)
                }
            } else {
                viewing = ViewerItem(day: day)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Day \(number), \(day.longName)\(filename == nil ? ", no photo" : "")")
        .accessibilityAddTraits(filename == nil ? [] : (isSelected ? [.isButton, .isSelected] : [.isButton]))
    }

    // MARK: Select

    private var selectionBar: some View {
        let urls = selection.sorted().compactMap { day in
            entries.first { $0.day == day }?.photoFilename.map(PhotoStore.url(for:))
        }
        return HStack(spacing: Tokens.Space.s) {
            ShareLink(items: urls) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(urls.isEmpty)
            Spacer()
            Text(selection.isEmpty ? "Pick photos" : "\(selection.count) selected")
                .font(Tokens.Font.subheadline)
                .foregroundStyle(Tokens.Colour.ink2)
            Spacer()
            Button("Compare") {
                let days = selection.sorted()
                withAnimation(.snappy) {
                    comparePair = (days[0], days[1])
                    isSelecting = false
                    selection = []
                }
            }
            .disabled(selection.count != 2)
        }
        .font(Tokens.Font.headline)
        .padding(.horizontal, Tokens.Space.m)
        .frame(minHeight: Tokens.Size.primaryButton)
        .background(.bar)
    }
}

#Preview("Photos") {
    PreviewHost { plan in PhotosScreen(plan: plan) }
}
