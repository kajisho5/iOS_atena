import Foundation

/// A rectangle in millimeters. Origin is the top-left corner of the sheet, y grows downwards.
public struct MMRect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }
}

public struct MMSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// Supported sheets, always described in portrait orientation.
public enum PaperKind: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Postcard, including New Year postcards (100 × 148 mm).
    case hagaki
    /// 長形3号 (120 × 235 mm).
    case nagagata3
    /// 長形4号 (90 × 205 mm).
    case nagagata4
    /// 洋形2号 (114 × 162 mm), used in portrait orientation.
    case yougata2
    /// 角形2号 (240 × 332 mm). Larger than A4; many home printers cannot feed it.
    case kakugata2

    public var id: String { rawValue }

    public var size: MMSize {
        switch self {
        case .hagaki: MMSize(width: 100, height: 148)
        case .nagagata3: MMSize(width: 120, height: 235)
        case .nagagata4: MMSize(width: 90, height: 205)
        case .yougata2: MMSize(width: 114, height: 162)
        case .kakugata2: MMSize(width: 240, height: 332)
        }
    }

    /// Whether the sheet is wider than A4 (210 mm) and may not fit home printers.
    public var exceedsA4Width: Bool { size.width > 210 }
}

/// Recipient postal-code boxes per Japan Post "郵便番号・バーコードマニュアル", specification 1 (JIS, 定形郵便物):
/// top edge 12.0 mm, right edge 8.0 mm (both ±1.5), boxes 5.7 × 8.0 mm, left edges at
/// 0 / 7.0 / 14.0 / 21.6 / 28.4 / 35.2 / 42.0 mm, total span 47.7 mm. Dimensions are measured
/// from the inside of the frame lines.
/// Source: https://www.post.japanpost.jp/service/search/zipcode/zipmanual/p05.html
public enum PostalFrame {
    public static let topMargin = 12.0
    public static let rightMargin = 8.0
    public static let boxWidth = 5.7
    public static let boxHeight = 8.0
    public static let boxOffsets: [Double] = [0, 7.0, 14.0, 21.6, 28.4, 35.2, 42.0]
    public static let totalSpan = 47.7

    /// Inner rectangles of the seven boxes for a sheet of the given width.
    public static func boxes(paperWidth: Double) -> [MMRect] {
        let left = paperWidth - rightMargin - totalSpan
        return boxOffsets.map { MMRect(x: left + $0, y: topMargin, width: boxWidth, height: boxHeight) }
    }

    /// Bottom of the frame row, used to place the address below it.
    public static var bottom: Double { topMargin + boxHeight }
}
