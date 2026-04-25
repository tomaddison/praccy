#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

/// Applies Nunito to `UINavigationBar` titles. Idempotent and safe to call from previews.
enum PraccyAppearance {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        #if canImport(UIKit)
        let inline = UIFont(name: "Nunito-ExtraBold", size: 17)
            ?? .systemFont(ofSize: 17, weight: .heavy)
        let large = UIFont(name: "Nunito-Black", size: 30)
            ?? .systemFont(ofSize: 30, weight: .black)
        let ink = UIColor(red: 0x1A / 255.0, green: 0x1A / 255.0, blue: 0x2E / 255.0, alpha: 1)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.font: inline, .foregroundColor: ink]
        appearance.largeTitleTextAttributes = [.font: large, .foregroundColor: ink]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // UIScrollView's 150ms touch-hold makes nested SwiftUI Buttons feel like tap-and-hold. SwiftUI buttons still cancel on drag.
        UIScrollView.appearance().delaysContentTouches = false
        #endif
    }
}
