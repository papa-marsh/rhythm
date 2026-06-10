//
//  Theme.swift
//  Rhythm
//
//  Design tokens from the spec (design_handoff_rhythm/README.md → Design
//  Tokens). Structural styling comes from native iOS components; these
//  tokens cover what the spec locks: accent, urgency tier colors, the
//  cadence color palette.
//

import SwiftUI
import UIKit

extension UIColor {
    /// Parse "#RRGGBB" (with or without the leading #).
    convenience init(hex: String) {
        var value: UInt64 = 0
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }

    /// A dynamic color that resolves per light/dark appearance.
    init(light: UIColor, dark: UIColor) {
        self.init(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            })
    }

    init(lightHex: String, darkHex: String) {
        self.init(light: UIColor(hex: lightHex), dark: UIColor(hex: darkHex))
    }
}

enum Theme {
    /// Locked accent: iOS system blue, lightened +16% in dark mode.
    static let accent = Color(lightHex: "#0A84FF", darkHex: "#3198FF")

    static let green = Color(lightHex: "#34C759", darkHex: "#30D158")
    static let orange = Color(lightHex: "#FF9500", darkHex: "#FF9F0A")
    static let red = Color(lightHex: "#FF3B30", darkHex: "#FF453A")

    /// Neutral for the `later` tier.
    static let neutral = Color(
        light: UIColor(red: 60 / 255, green: 60 / 255, blue: 67 / 255, alpha: 0.45),
        dark: UIColor(red: 235 / 255, green: 235 / 255, blue: 245 / 255, alpha: 0.4)
    )

    static func tierColor(_ tier: UrgencyTier) -> Color {
        switch tier {
        case .later: neutral
        case .almost, .due: accent
        case .overdue: orange
        case .late: red
        }
    }

    /// Curated palette for cadence/beat identity tiles.
    static let palette: [String] = [
        "#5E5CE6", "#34C759", "#FF9500", "#FF2D55", "#0A84FF", "#AF52DE",
        "#FFCC00", "#30D158", "#64D2FF", "#A2845E", "#FF6B35", "#8E8E93",
    ]
}
