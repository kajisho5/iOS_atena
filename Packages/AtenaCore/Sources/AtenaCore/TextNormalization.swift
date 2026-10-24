import Foundation

/// Character-level normalization helpers shared by import, validation and layout.
public enum TextNormalization {
    /// Characters treated as a hyphen in addresses and postal codes.
    public static let hyphenLikeCharacters: Set<Character> = [
        "-", "\u{2010}", "\u{2011}", "\u{2012}", "\u{2013}", "\u{2014}", "\u{2015}",
        "\u{2212}", "\u{FF0D}", "\u{FE63}", "\u{30FC}", "\u{FF70}",
    ]

    /// Converts full-width ASCII digits (０-９) to half-width (0-9). Other characters are kept.
    public static func halfWidthDigits(_ text: String) -> String {
        String(text.map { character -> Character in
            guard let scalar = character.unicodeScalars.first,
                  character.unicodeScalars.count == 1,
                  (0xFF10...0xFF19).contains(scalar.value),
                  let converted = Unicode.Scalar(scalar.value - 0xFF10 + 0x30)
            else { return character }
            return Character(converted)
        })
    }

    /// Removes regular and ideographic spaces; used for duplicate detection keys.
    public static func removingSpaces(_ text: String) -> String {
        text.filter { !$0.isWhitespace }
    }

    /// Trims whitespace (including ideographic space) and newlines.
    public static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Japanese postal code (7 digits).
public enum PostalCode {
    /// Extracts the digits of a postal code written in common forms
    /// ("〒123-4567", "１２３－４５６７", "1234567"). Returns nil when the result is not 7 digits.
    public static func normalize(_ raw: String) -> String? {
        let digits = digitsOnly(raw)
        return digits.count == 7 ? digits : nil
    }

    /// Returns only the ASCII digits found in `raw` (full-width digits are converted).
    public static func digitsOnly(_ raw: String) -> String {
        TextNormalization.halfWidthDigits(raw).filter { $0.isASCII && $0.isNumber }
    }

    /// Formats 7 digits as "123-4567". Returns the input unchanged when it is not 7 digits.
    public static func formatted(_ digits: String) -> String {
        guard digits.count == 7, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return digits }
        return "\(digits.prefix(3))-\(digits.suffix(4))"
    }
}
