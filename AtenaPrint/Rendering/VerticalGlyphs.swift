import Foundation

/// How a character is drawn inside a vertical (tategaki) cell.
nonisolated enum VerticalGlyphStyle {
    /// Drawn upright, centered in the cell.
    case upright
    /// Rotated 90° clockwise (long vowel mark, dashes, brackets, tildes).
    case rotated
    /// Small kana: upright, nudged towards the upper right.
    case smallKana
    /// Ideographic comma/full stop: placed in the upper-right quadrant.
    case punctuation
}

nonisolated enum VerticalGlyphs {
    private static let rotated: Set<Character> = [
        "ー", "―", "‐", "-", "－", "—", "–", "〜", "～", "~", "…", "‥",
        "（", "）", "(", ")", "「", "」", "『", "』", "［", "］", "【", "】", "〈", "〉", "《", "》", "｛", "｝",
        "＝", "=", "：", ":", "；", ";",
    ]
    private static let small: Set<Character> = [
        "ぁ", "ぃ", "ぅ", "ぇ", "ぉ", "っ", "ゃ", "ゅ", "ょ", "ゎ",
        "ァ", "ィ", "ゥ", "ェ", "ォ", "ッ", "ャ", "ュ", "ョ", "ヮ", "ヵ", "ヶ",
    ]
    private static let punctuation: Set<Character> = ["、", "。", "，", "．", ",", "."]

    static func style(for character: Character) -> VerticalGlyphStyle {
        if rotated.contains(character) { return .rotated }
        if small.contains(character) { return .smallKana }
        if punctuation.contains(character) { return .punctuation }
        return .upright
    }
}
