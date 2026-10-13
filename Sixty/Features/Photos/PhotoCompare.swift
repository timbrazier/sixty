import SwiftUI
import SixtyCore

/// Two days' photos compared, either side by side or stacked with a
/// draggable divider.
struct PhotoCompare: View {
    enum Mode: String, CaseIterable {
        case sideBySide, slider

        var title: String {
            switch self {
            case .sideBySide: "Side by side"
            case .slider: "Slider"
            }
        }
    }

    struct Side {
        let dayNumber: Int
        let day: DayKey
        let filename: String?
    }

    let left: Side
    let right: Side
    var mode: Mode = .sideBySide

    var body: some View {
        switch mode {
        case .sideBySide: sideBySide
        case .slider: SliderCompare(left: left, right: right)
        }
    }

    private var sideBySide: some View {
        HStack(alignment: .top, spacing: Tokens.Space.s) {
            column(left)
            column(right)
        }
    }

    private func column(_ side: Side) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            ComparePhoto(filename: side.filename)
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.list))
            CompareCaption(side: side)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Day \(side.dayNumber), \(side.day.longName)\(side.filename == nil ? ", no photo" : "")")
    }
}

/// "Day 1  30 Sep"
struct CompareCaption: View {
    let side: PhotoCompare.Side

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: Tokens.Space.xs) {
            Text("Day \(side.dayNumber)")
                .font(Tokens.Font.stat(22))
                .foregroundStyle(Tokens.Colour.ink)
            Text(side.day.startDate().formatted(.dateTime.day().month(.abbreviated)))
                .font(Tokens.Font.footnoteRegular)
                .foregroundStyle(Tokens.Colour.ink2)
        }
    }
}

/// A photo, or the hatch with "No photo yet".
struct ComparePhoto: View {
    let filename: String?

    var body: some View {
        if let filename {
            Color.clear.overlay { PhotoThumbnail(filename: filename, maxPixel: 1600) }.clipped()
        } else {
            Hatch()
                .overlay {
                    Text("No photo yet")
                        .font(Tokens.Font.footnoteRegular)
                        .foregroundStyle(Tokens.Colour.ink2)
                }
        }
    }
}

/// The later photo underneath, the earlier one revealed to the left of a
/// draggable divider.
struct SliderCompare: View {
    let left: PhotoCompare.Side
    let right: PhotoCompare.Side
    @State private var split: CGFloat = 0.5

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    ComparePhoto(filename: right.filename)
                    ComparePhoto(filename: left.filename)
                        .mask(alignment: .leading) {
                            Rectangle().frame(width: width * split)
                        }
                    Rectangle()
                        .fill(.white)
                        .frame(width: 2)
                        .overlay {
                            Image(systemName: "arrow.left.and.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Tokens.Colour.ink)
                                .frame(width: 32, height: 32)
                                .background(.white, in: Circle())
                                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                        }
                        .offset(x: width * split - 1)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        split = min(max(value.location.x / width, 0), 1)
                    }
                )
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.photo))
            .accessibilityElement()
            .accessibilityLabel("Comparison of Day \(left.dayNumber) and Day \(right.dayNumber)")
            .accessibilityValue("\(Int(split * 100)) percent Day \(left.dayNumber)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: split = min(split + 0.1, 1)
                case .decrement: split = max(split - 0.1, 0)
                @unknown default: break
                }
            }

            HStack {
                CompareCaption(side: left)
                Spacer()
                CompareCaption(side: right)
            }
        }
    }
}
