import SwiftUI
import UIKit

/// The site's design system, verbatim. COLOR LAW: the red never changes between themes.
enum Theme {
    // Constants in both themes
    static let red = Color(red: 0x8A / 255, green: 0x10 / 255, blue: 0x16 / 255)
    static let redBright = Color(red: 0xAD / 255, green: 0x16 / 255, blue: 0x20 / 255)

    // Light / dark pairs
    static func paper(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0x12 / 255, green: 0x12 / 255, blue: 0x12 / 255)
                        : Color(red: 0xFA / 255, green: 0xF9 / 255, blue: 0xF7 / 255)
    }
    static func paperDeep(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0x1D / 255, green: 0x1D / 255, blue: 0x1D / 255)
                        : Color(red: 0xF0 / 255, green: 0xEE / 255, blue: 0xEA / 255)
    }
    static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0xE9 / 255, green: 0xE7 / 255, blue: 0xE3 / 255)
                        : Color(red: 0x1C / 255, green: 0x1B / 255, blue: 0x1A / 255)
    }
    static func inkSoft(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0x9A / 255, green: 0x97 / 255, blue: 0x93 / 255)
                        : Color(red: 0x5C / 255, green: 0x59 / 255, blue: 0x55 / 255)
    }
    static func rule(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0x2A / 255, green: 0x2A / 255, blue: 0x2A / 255)
                        : Color(red: 0xE2 / 255, green: 0xDF / 255, blue: 0xDA / 255)
    }
}

/// Runtime font resolution: the ttf conversions may carry any internal PostScript
/// names, so resolve once by scanning the registered families.
enum Fonts {
    private static let resolved: (serif400: String, serif400i: String, serif500: String,
                                  serif600: String, sans400: String, sans500: String,
                                  sans600: String, sans700: String) = {
        var garamond: [String] = []
        var instrument: [String] = []
        for family in UIFont.familyNames {
            let names = UIFont.fontNames(forFamilyName: family)
            if family.localizedCaseInsensitiveContains("Garamond") { garamond += names }
            if family.localizedCaseInsensitiveContains("Instrument") { instrument += names }
        }
        func pick(_ names: [String], _ needles: [String], fallback: String) -> String {
            for needle in needles {
                if let hit = names.first(where: { $0.localizedCaseInsensitiveContains(needle) }) { return hit }
            }
            return names.first ?? fallback
        }
        let g400 = pick(garamond.filter { !$0.localizedCaseInsensitiveContains("Italic") },
                        ["Regular"], fallback: "Georgia")
        let g400i = pick(garamond, ["Italic"], fallback: g400)
        let g500 = pick(garamond, ["Medium"], fallback: g400)
        let g600 = pick(garamond, ["SemiBold", "Semibold", "DemiBold"], fallback: g500)
        let s400 = pick(instrument, ["Regular"], fallback: "HelveticaNeue")
        let s500 = pick(instrument, ["Medium"], fallback: s400)
        let s600 = pick(instrument, ["SemiBold", "Semibold"], fallback: s500)
        let s700 = pick(instrument, ["Bold"], fallback: s600)
        return (g400, g400i, g500, g600, s400, s500, s600, s700)
    }()

    static func serif(_ size: CGFloat, weight: Int = 400, italic: Bool = false) -> Font {
        let name: String
        if italic { name = resolved.serif400i }
        else {
            switch weight {
            case ..<450: name = resolved.serif400
            case ..<550: name = resolved.serif500
            default: name = resolved.serif600
            }
        }
        return .custom(name, size: size)
    }

    static func sans(_ size: CGFloat, weight: Int = 400) -> Font {
        let name: String
        switch weight {
        case ..<450: name = resolved.sans400
        case ..<550: name = resolved.sans500
        case ..<650: name = resolved.sans600
        default: name = resolved.sans700
        }
        return .custom(name, size: size)
    }
}
