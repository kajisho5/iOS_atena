import Foundation

/// Converts Arabic digits to kanji numerals digit by digit ("1-13-3" → "一-一三-三").
/// Positional notation ("十三") and "丁目/番/号" rewriting are intentionally not performed.
public enum KanjiNumeralConverter {
    private static let numerals: [Character] = ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

    public static func convert(_ text: String) -> String {
        String(TextNormalization.halfWidthDigits(text).map { character -> Character in
            guard character.isASCII, let value = character.wholeNumberValue else { return character }
            return numerals[value]
        })
    }
}

/// Prepares text for vertical (tategaki) typesetting.
///
/// - Hyphen-like characters that sit between numerals become "―" (U+2015), which Japanese
///   fonts render as a vertical bar in vertical text. Katakana prolonged sound marks inside
///   words (e.g. "ハイツ") are left alone.
/// - Remaining ASCII digits and Latin letters become full-width so they stand upright.
/// - ASCII spaces become ideographic spaces.
public enum VerticalTextNormalizer {
    public static let verticalHyphen: Character = "\u{2015}"

    public static func normalize(_ text: String, convertDigitsToKanji: Bool) -> String {
        let source = convertDigitsToKanji ? KanjiNumeralConverter.convert(text) : TextNormalization.halfWidthDigits(text)
        let characters = Array(source)
        var result = String()
        result.reserveCapacity(characters.count)
        for (index, character) in characters.enumerated() {
            if TextNormalization.hyphenLikeCharacters.contains(character),
               isNumeral(characters, index - 1), isNumeral(characters, index + 1) {
                result.append(verticalHyphen)
            } else if character == " " {
                result.append("\u{3000}")
            } else if character.isASCII, let scalar = character.unicodeScalars.first,
                      character.isLetter || character.isNumber,
                      let fullWidth = Unicode.Scalar(scalar.value + 0xFEE0) {
                result.append(Character(fullWidth))
            } else {
                result.append(character)
            }
        }
        return result
    }

    private static let kanjiNumerals: Set<Character> = ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

    private static func isNumeral(_ characters: [Character], _ index: Int) -> Bool {
        guard characters.indices.contains(index) else { return false }
        let character = characters[index]
        if kanjiNumerals.contains(character) { return true }
        return TextNormalization.halfWidthDigits(String(character)).first.map { $0.isASCII && $0.isNumber } ?? false
    }
}

/// Cell sizes used when setting vertical text one character per cell.
public enum VerticalMetrics {
    /// Advance of one character in em units: an ASCII space is a half-em gap, everything else a full cell.
    public static func advance(of character: Character) -> Double {
        character == " " ? 0.5 : 1.0
    }

    public static func advance(of text: String) -> Double {
        text.reduce(0) { $0 + advance(of: $1) }
    }
}
