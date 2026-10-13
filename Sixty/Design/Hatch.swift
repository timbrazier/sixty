import SwiftUI

/// Diagonal stripes in the hatch colour: missed days in the grid, and the
/// placeholder where a photo is missing or still loading.
struct Hatch: View {
    var spacing: CGFloat = 14
    var lineWidth: CGFloat = 6
    var background = Tokens.Colour.surface

    var body: some View {
        Canvas { context, size in
            let stripe = Tokens.Colour.hatch.opacity(0.55)
            var path = Path()
            var x = -size.height
            while x < size.width {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += spacing
            }
            context.stroke(path, with: .color(stripe), lineWidth: lineWidth)
        }
        .background(background)
        .accessibilityHidden(true)
    }
}
