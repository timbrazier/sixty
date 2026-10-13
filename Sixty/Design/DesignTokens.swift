import SwiftUI
import UIKit

/// Design tokens from the Sixty design file ("Tokens" sheet).
/// Accent is the only saturated colour. Dark mode lifts the accent and flips
/// accent-ink to near-black so checkmarks keep contrast.
enum Tokens {
    enum Colour {
        /// Screen background.
        static let bg = Color(light: 0xF4F2EE, dark: 0x0E0E0D)
        /// Bib, lists, cards.
        static let surface = Color(light: 0xFFFFFF, dark: 0x1B1A19)
        /// Controls, ring track, chips.
        static let surface2 = Color(light: 0xEAE7E1, dark: 0x272523)
        /// Primary text, today marker.
        static let ink = Color(light: 0x1B1A18, dark: 0xF3F1EC)
        /// Secondary text, section headers.
        static let ink2 = Color(light: 0x5E5A54, dark: 0xABA69E)
        /// Placeholders, inactive tabs, "of 60".
        static let ink3 = Color(light: 0x7D7870, dark: 0x7E7972)
        /// Separators.
        static let line = Color(light: 0xDDD9D2, dark: 0x2F2D2A)
        /// Upcoming-day outline.
        static let line2 = Color(light: 0xCFCAC2, dark: 0x3A3835)
        /// Missed-day stripes.
        static let hatch = Color(light: 0xC9C4BC, dark: 0x45423E)
        /// Progress, completed, primary action. Track orange.
        static let accent = Color(light: 0xC63F19, dark: 0xF26B42)
        /// Glyphs and text on accent.
        static let accentInk = Color(light: 0xFFFFFF, dark: 0x1A0D08)
        /// Day-complete banner.
        static let accentSoft = Color(light: 0xF7E2D9, dark: 0x3B1F15)
    }

    enum Space {
        /// Bar gaps, cell gap.
        static let xxs: CGFloat = 4
        /// Tile gaps, label → field.
        static let xs: CGFloat = 8
        /// Card → card.
        static let s: CGFloat = 12
        /// Screen margin, row padding.
        static let m: CGFloat = 16
        /// Bib padding.
        static let l: CGFloat = 20
        /// Section → section.
        static let xl: CGFloat = 24
        /// Section header inset.
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let gridCell: CGFloat = 7
        static let chip: CGFloat = 12
        static let banner: CGFloat = 12
        static let list: CGFloat = 14
        static let button: CGFloat = 14
        static let bib: CGFloat = 20
        static let photo: CGFloat = 20
        static let notification: CGFloat = 22
    }

    enum Size {
        /// Tap rows: whole row is the target.
        static let row: CGFloat = 52
        static let stepperVisual: CGFloat = 40
        static let minHit: CGFloat = 44
        static let primaryButton: CGFloat = 54
    }

    /// SF styles track Dynamic Type. The bib number scales to AX1 then holds;
    /// at accessibility sizes the ring moves below the number and list rows
    /// grow in height rather than truncating.
    enum Font {
        static let condensed = "BarlowCondensed-Bold"

        /// Day number on the bib: 124/0.8 (104 on the day picker).
        static func bib(_ size: CGFloat = 124) -> SwiftUI.Font {
            .custom(condensed, size: size, relativeTo: .largeTitle)
        }

        /// Stats: 36 / 28 / 22.
        static func stat(_ size: CGFloat = 36) -> SwiftUI.Font {
            .custom(condensed, size: size, relativeTo: .title)
        }

        static let largeTitle = SwiftUI.Font.largeTitle.bold()      // 34/41
        static let title3 = SwiftUI.Font.title3.weight(.semibold)   // 20/25
        static let headline = SwiftUI.Font.headline                 // 17/22 semibold
        static let body = SwiftUI.Font.body                         // 17/22
        static let subheadline = SwiftUI.Font.subheadline           // 15/20
        /// Section labels: footnote semibold 13/18, set in caps with tracking.
        static let sectionLabel = SwiftUI.Font.footnote.weight(.semibold)
        static let caption2 = SwiftUI.Font.caption2                 // 11/13
    }

    enum Motion {
        /// Tick: circle fills from the centre with a slight overshoot.
        static let tickFill = Animation.spring(duration: 0.16, bounce: 0.35)
        /// Tick: check stroke draws in.
        static let tickStroke = Animation.easeOut(duration: 0.2)
        /// Ring advances one segment.
        static let ring = Animation.easeOut(duration: 0.35)
        /// Auto-save fires after this much inactivity.
        static let autosaveDelay: Duration = .milliseconds(500)
    }
}

extension Color {
    /// A colour that switches with light and dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension View {
    /// Section header: footnote semibold caps in ink-2, e.g. "ACTIVITIES".
    func sectionLabelStyle() -> some View {
        self.font(Tokens.Font.sectionLabel)
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(Tokens.Colour.ink2)
    }
}
