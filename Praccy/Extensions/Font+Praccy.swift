import SwiftUI
import UIKit

// Nunito is registered via `UIAppFonts` in Info.plist. `.system(design: .rounded)`
// is a release-only safety net if a TTF fails to register.
private enum Nunito {
    static let bold = "Nunito-Bold"           // 700
    static let extraBold = "Nunito-ExtraBold" // 800
    static let black = "Nunito-Black"         // 900

    static func isAvailable(_ name: String) -> Bool {
        UIFont(name: name, size: 17) != nil
    }
}

private func praccyFont(
    _ nunito: String,
    size: CGFloat,
    fallbackWeight: Font.Weight,
    relativeTo style: Font.TextStyle
) -> Font {
    assert(Nunito.isAvailable(nunito), "⚠️ '\(nunito)' not registered - check UIAppFonts in Info.plist and Copy Bundle Resources.")
    guard Nunito.isAvailable(nunito) else {
        return .system(size: size, weight: fallbackWeight, design: .rounded)
            .leading(.tight)
    }
    return .custom(nunito, size: size, relativeTo: style)
        .leading(.tight)
}

// Each role is scaled `relativeTo:` a UIKit text style so Dynamic Type preserves the hierarchy at AX sizes.
enum PraccyFont {
    /// 56pt / 900 / -2 tracking. Hero display on the identity page.
    static var display: Font {
        praccyFont(Nunito.black, size: 56, fallbackWeight: .black, relativeTo: .largeTitle)
    }

    /// 30pt / 900 / -0.6 tracking. Screen titles.
    static var title: Font {
        praccyFont(Nunito.black, size: 30, fallbackWeight: .black, relativeTo: .title)
    }

    /// 20pt / 900 / -0.3 tracking. Section headers.
    static var section: Font {
        praccyFont(Nunito.black, size: 20, fallbackWeight: .black, relativeTo: .title3)
    }

    /// 17pt / 800 / -0.2 tracking. Task card titles, body CTAs.
    static var task: Font {
        praccyFont(Nunito.extraBold, size: 17, fallbackWeight: .heavy, relativeTo: .body)
    }

    /// 16pt / 700. Meta / caption rows.
    static var meta: Font {
        praccyFont(Nunito.bold, size: 16, fallbackWeight: .bold, relativeTo: .subheadline)
    }

    /// 14pt / 900 / uppercase / +1 tracking. "EYEBROW" labels.
    static var eyebrow: Font {
        praccyFont(Nunito.black, size: 14, fallbackWeight: .black, relativeTo: .caption)
    }
}

// Tracking is applied via `.tracking()` rather than baked into the Font so Dynamic Type still scales.
extension Text {
    func praccyDisplay() -> Text { font(PraccyFont.display).tracking(-2) }
    func praccyTitle() -> Text { font(PraccyFont.title).tracking(-0.6) }
    func praccySection() -> Text { font(PraccyFont.section).tracking(-0.3) }
    func praccyTask() -> Text { font(PraccyFont.task).tracking(-0.2) }
    func praccyMeta() -> Text { font(PraccyFont.meta) }
}

extension View {
    func praccyEyebrow() -> some View {
        font(PraccyFont.eyebrow)
    }
}
