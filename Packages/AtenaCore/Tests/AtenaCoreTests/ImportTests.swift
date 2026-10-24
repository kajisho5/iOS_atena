import Testing
@testable import AtenaCore

@Suite struct ColumnMappingTests {
    @Test func mapsJapaneseHeaders() {
        let mapping = ColumnMapping.automatic(headers: ["名前", "〒", "住所", "建物名", "備考", "連名", "フリガナ"])
        #expect(mapping[.name] == 0)
        #expect(mapping[.postalCode] == 1)
        #expect(mapping[.address1] == 2)
        #expect(mapping[.address2] == 3)
        #expect(mapping[.memo] == 4)
        #expect(mapping[.jointNames] == 5)
        #expect(mapping[.nameKana] == 6)
        #expect(mapping[.honorific] == nil)
    }

    @Test func templateHeadersMapBackToTheirFields() {
        let headers = CSVTemplate.templateRows()[0]
        let mapping = ColumnMapping.automatic(headers: headers)
        for (index, field) in RecipientField.templateFields.enumerated() {
            #expect(mapping[field] == index)
        }
    }

    @Test func templateOrderWithoutHeader() {
        let mapping = ColumnMapping.templateOrder(columnCount: 3)
        #expect(mapping[.name] == 0)
        #expect(mapping[.jointNames] == 1)
        #expect(mapping[.postalCode] == 2)
        #expect(mapping[.address1] == nil)
    }
}

@Suite struct ImportPlannerTests {
    let header = ["氏名", "連名", "郵便番号", "住所", "メモ"]

    @Test func classifiesRows() {
        let rows = [
            header,
            ["山田 太郎", "花子・一郎", "〒104-0061", "東京都中央区見本町1-13-3", ""],
            ["", "", "1000001", "東京都", ""],
            ["山田太郎", "", "1040061", "東京都中央区", ""],
            ["佐藤 一郎", "", "12345", "", "喪中"],
            ["", "", "", "", ""],
            ["鈴木 次郎", "", "5300001", "大阪府", ""],
        ]
        let existing: Set<String> = [DuplicateKey.make(name: "鈴木次郎", postalCode: "530-0001")]
        let plan = ImportPlanner.plan(rows: rows, hasHeader: true, mapping: .automatic(headers: header), existingKeys: existing)
        #expect(plan.map(\.id) == [2, 3, 4, 5, 7])
        #expect(plan[0].status == .ready)
        #expect(plan[0].draft.jointNames == ["花子", "一郎"])
        #expect(plan[0].draft.postalCode == "1040061")
        #expect(plan[0].draft.honorific == "様")
        #expect(plan[1].status == .missingName)
        #expect(plan[2].status == .possibleDuplicate)
        #expect(plan[2].isIncluded == false)
        #expect(plan[3].status == .ready)
        #expect(plan[3].warnings == [.invalidPostalCode, .missingAddress])
        #expect(plan[4].status == .possibleDuplicate)
    }

    @Test func freeTierRemainingSlots() {
        #expect(FreeTier.remainingSlots(currentCount: 8, isPro: false) == 2)
        #expect(FreeTier.remainingSlots(currentCount: 12, isPro: false) == 0)
        #expect(FreeTier.remainingSlots(currentCount: 12, isPro: true) == Int.max)
    }
}
