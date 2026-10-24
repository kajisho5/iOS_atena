import CoreText
import Foundation

/// Fonts bundled with iOS (no licensing concerns). Falls back to the system font if missing.
nonisolated enum AddressFont: String, CaseIterable, Codable, Identifiable, Sendable {
    case mincho
    case gothic
    case maruGothic

    var id: String { rawValue }

    var postScriptName: String {
        switch self {
        case .mincho: "HiraMinProN-W3"
        case .gothic: "HiraginoSans-W3"
        case .maruGothic: "HiraMaruProN-W4"
        }
    }

    var localizedName: String {
        switch self {
        case .mincho: String(localized: "font.mincho")
        case .gothic: String(localized: "font.gothic")
        case .maruGothic: String(localized: "font.maruGothic")
        }
    }

    /// Core Text font at the given size in points.
    func ctFont(size: CGFloat) -> CTFont {
        let font = CTFontCreateWithName(postScriptName as CFString, size, nil)
        if (CTFontCopyPostScriptName(font) as String) == postScriptName {
            return font
        }
        return CTFontCreateUIFontForLanguage(.system, size, "ja" as CFString) ?? font
    }
}
