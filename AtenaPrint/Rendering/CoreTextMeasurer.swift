import AtenaCore
import CoreText
import Foundation

/// Measures text with Core Text. Vertical text is set one character per em cell (spaces are half
/// cells), so its advance does not depend on glyph metrics; horizontal text uses real glyph advances.
nonisolated struct CoreTextMeasurer: TextMeasuring {
    let font: AddressFont

    private static let referenceSize: CGFloat = 100

    func advance(of text: String, vertical: Bool) -> Double {
        if vertical {
            return VerticalMetrics.advance(of: text)
        }
        let attributed = NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font.ctFont(size: Self.referenceSize),
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        return Double(CTLineGetTypographicBounds(line, nil, nil, nil)) / Double(Self.referenceSize)
    }
}
