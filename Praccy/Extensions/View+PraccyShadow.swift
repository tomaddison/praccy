import SwiftUI

extension View {
    /// Solid colour offset shadow. The only shadow style used in the app.
    func praccySolidShadow(color: Color, offset: CGFloat = 4) -> some View {
        compositingGroup().shadow(color: color, radius: 0, x: 0, y: offset)
    }
}
