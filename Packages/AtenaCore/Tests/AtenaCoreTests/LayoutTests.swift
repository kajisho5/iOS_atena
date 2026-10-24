import Testing
@testable import AtenaCore

/// Full-width characters are 1 em, ASCII is 0.5 em.
struct FixedWidthMeasurer: TextMeasuring {
    func advance(of text: String, vertical: Bool) -> Double {
        text.reduce(0) { $0 + ($1.isASCII ? 0.5 : 1.0) }
    }
}

@Suite struct PostalFrameTests {
    @Test func hagakiBoxesMatchJapanPostSpecification() {
        let boxes = PostalFrame.boxes(paperWidth: 100)
        #expect(boxes.count == 7)
        #expect(abs(boxes[0].x - 44.3) < 0.0001)
        #expect(abs(boxes[6].maxX - 92.0) < 0.0001)
        #expect(boxes.allSatisfy { $0.y == 12 && $0.width == 5.7 && $0.height == 8 })
        // Gap between the 3rd and 4th box holds the hyphen.
        #expect(abs((boxes[3].x - boxes[2].maxX) - 1.9) < 0.0001)
    }
}

@Suite struct AddressLayoutTests {
    let engine = AddressLayoutEngine(measurer: FixedWidthMeasurer())
    let content = AddressContent(name: "山田 太郎", jointNames: ["花子"], honorific: "様", postalCode: "104-0061",
                                 address1: "東京都中央区見本町1-13-3", address2: "サンプルハイツ203")
    let sender = SenderContent(name: "田中 一郎", postalCode: "1230045", address1: "東京都見本区見本町2-5")

    @Test(arguments: PaperKind.allCases, WritingMode.allCases)
    func typicalAddressFitsWithinSheet(paper: PaperKind, mode: WritingMode) {
        let result = engine.layout(content, options: LayoutOptions(paper: paper, writingMode: mode, sender: sender))
        #expect(!result.hasOverflow, "\(paper) \(mode): \(result.overflowingRoles)")
        for run in result.runs {
            #expect(run.frame.x >= 0 && run.frame.y >= 0, "\(run.text)")
            #expect(run.frame.maxX <= paper.size.width + 0.001 && run.frame.maxY <= paper.size.height + 0.001, "\(paper) \(mode) \(run.text) \(run.frame)")
        }
        #expect(result.runs.filter { $0.role == .recipientPostalCode }.count == 7)
    }

    @Test func verticalNameColumnsAlignHonorifics() {
        let result = engine.layout(content, options: LayoutOptions(paper: .hagaki, writingMode: .vertical))
        let names = result.runs.filter { $0.role == .recipientName }
        #expect(names.map(\.text) == ["山田 太郎 様", "花子 様"])
        #expect(abs(names[0].frame.maxY - names[1].frame.maxY) < 0.0001)
        #expect(names[1].frame.x < names[0].frame.x)
    }

    @Test func verticalAddressUsesKanjiNumeralsAndVerticalHyphen() {
        let result = engine.layout(content, options: LayoutOptions(paper: .hagaki, writingMode: .vertical, convertDigitsToKanji: true))
        let address = result.runs.filter { $0.role == .recipientAddress }.map(\.text)
        #expect(address == ["東京都中央区見本町一―一三―三", "サンプルハイツ二〇三"])
    }

    @Test func horizontalKeepsArabicDigits() {
        let result = engine.layout(content, options: LayoutOptions(paper: .hagaki, writingMode: .horizontal, convertDigitsToKanji: true))
        let address = result.runs.filter { $0.role == .recipientAddress }.map(\.text)
        #expect(address == ["東京都中央区見本町1-13-3", "サンプルハイツ203"])
    }

    @Test func longAddressWrapsIntoAnotherColumn() {
        var long = content
        long.address1 = "北海道札幌市中央区見本通り西二十八丁目見本ビルディング東棟二十三階見本株式会社総務部"
        long.address2 = ""
        let result = engine.layout(long, options: LayoutOptions(paper: .hagaki, writingMode: .vertical))
        let address = result.runs.filter { $0.role == .recipientAddress }
        #expect(address.count == 2)
        #expect(!result.overflowingRoles.contains(.recipientAddress))
        #expect(address.map(\.text).joined() == long.address1)
    }

    @Test func impossibleAddressReportsOverflow() {
        var huge = content
        huge.address1 = String(repeating: "見本", count: 80)
        huge.address2 = String(repeating: "建物", count: 40)
        let result = engine.layout(huge, options: LayoutOptions(paper: .hagaki, writingMode: .vertical))
        #expect(result.overflowingRoles.contains(.recipientAddress))
    }

    @Test func missingPostalCodePrintsNoDigits() {
        var noPostal = content
        noPostal.postalCode = ""
        let result = engine.layout(noPostal, options: LayoutOptions())
        #expect(result.runs.allSatisfy { $0.role != .recipientPostalCode })
        #expect(result.postalFrames.count == 7)
    }
}
