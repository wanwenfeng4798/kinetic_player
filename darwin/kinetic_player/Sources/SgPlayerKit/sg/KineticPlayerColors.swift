#if os(iOS)
import UIKit

/// Shared seek-bar / chrome accent colors (default Bilibili pink `#FB7299`).
enum KineticPlayerColors {
    private static let defaultAccent = UIColor(
        red: 251.0 / 255.0,
        green: 114.0 / 255.0,
        blue: 153.0 / 255.0,
        alpha: 1,
    )

    static var accent: UIColor = defaultAccent
    static var seekActive: UIColor { accent }
    static let seekBackground = UIColor(white: 1, alpha: 0.35)
    static let panelBackground = UIColor(white: 0, alpha: 0.6)

    static func applyAccent(argb: Int) {
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0
        accent = UIColor(red: r, green: g, blue: b, alpha: a > 0 ? a : 1)
    }
}
#elseif os(macOS)
import AppKit

/// Shared seek-bar / chrome accent colors (default Bilibili pink `#FB7299`).
enum KineticPlayerColors {
    private static let defaultAccent = NSColor(
        red: 251.0 / 255.0,
        green: 114.0 / 255.0,
        blue: 153.0 / 255.0,
        alpha: 1,
    )

    static var accent: NSColor = defaultAccent
    static var seekActive: NSColor { accent }
    static let seekBackground = NSColor(white: 1, alpha: 0.35)
    static let panelBackground = NSColor(white: 0, alpha: 0.6)

    static func applyAccent(argb: Int) {
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0
        accent = NSColor(red: r, green: g, blue: b, alpha: a > 0 ? a : 1)
    }
}
#endif
