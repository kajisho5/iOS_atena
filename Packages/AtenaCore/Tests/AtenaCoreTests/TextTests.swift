import Testing
@testable import AtenaCore

@Suite struct PostalCodeTests {
    @Test(arguments: [
        ("〒104-0061", "1040061"),
        ("１０４－００６１", "1040061"),
        ("104 0061", "1040061"),
        ("1040061", "1040061"),
        ("104ー0061", "1040061"),
    ])
    func normalizesCommonForms(input: String, expected: String) {
        #expect(PostalCode.normalize(input) == expected)
    }

    @Test func rejectsWrongLength() {
        #expect(PostalCode.normalize("104-006") == nil)
        #expect(PostalCode.normalize("") == nil)
    }

    @Test func formats() {
        #expect(PostalCode.formatted("1040061") == "104-0061")
        #expect(PostalCode.formatted("12") == "12")
    }
}

@Suite struct KanjiNumeralTests {
    @Test func convertsDigitByDigit() {
        #expect(KanjiNumeralConverter.convert("1-13-3") == "一-一三-三")
        #expect(KanjiNumeralConverter.convert("２０３号") == "二〇三号")
        #expect(KanjiNumeralConverter.convert("見本町") == "見本町")
    }
}

@Suite struct VerticalTextNormalizerTests {
    @Test func replacesHyphensBetweenNumeralsOnly() {
        #expect(VerticalTextNormalizer.normalize("見本町1-13-3", convertDigitsToKanji: true) == "見本町一―一三―三")
        #expect(VerticalTextNormalizer.normalize("サンプルハイツ203", convertDigitsToKanji: true) == "サンプルハイツ二〇三")
    }

    @Test func makesDigitsFullWidthWithoutKanjiConversion() {
        #expect(VerticalTextNormalizer.normalize("1-13-3 A棟", convertDigitsToKanji: false) == "１―１３―３\u{3000}Ａ棟")
    }

    @Test func keepsProlongedSoundMarkInWords() {
        #expect(VerticalTextNormalizer.normalize("コーポ5ー2", convertDigitsToKanji: true) == "コーポ五―二")
    }
}
