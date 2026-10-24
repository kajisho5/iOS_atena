import Foundation
import Testing
@testable import AtenaCore

@Suite struct CSVParserTests {
    @Test func parsesQuotedFieldsAndLineBreaks() {
        let text = "氏名,住所\r\n\"山田, 太郎\",\"東京都\n見本町\"\r\n\"引用\"\"符\",x\n"
        let rows = CSVParser.parse(text)
        #expect(rows == [["氏名", "住所"], ["山田, 太郎", "東京都\n見本町"], ["引用\"符", "x"]])
    }

    @Test func handlesMissingTrailingNewlineAndEmptyFields() {
        #expect(CSVParser.parse("a,,c") == [["a", "", "c"]])
        #expect(CSVParser.parse("a\n\nb\n") == [["a"], ["b"]])
        // A line holding only an empty quoted field is treated as a blank line.
        #expect(CSVParser.parse("\"\"").isEmpty)
    }

    @Test func handlesCROnlyLineEndings() {
        #expect(CSVParser.parse("a,b\rc,d\r") == [["a", "b"], ["c", "d"]])
    }
}

@Suite struct CSVDecoderTests {
    @Test func detectsUTF8WithBOM() throws {
        let data = Data([0xEF, 0xBB, 0xBF]) + Data("氏名\n山田".utf8)
        let result = try CSVTextDecoder.decode(data)
        #expect(result.encoding == .utf8)
        #expect(result.text == "氏名\n山田")
    }

    @Test func detectsShiftJIS() throws {
        // "氏名" in Shift_JIS.
        let data = Data([0x8E, 0x81, 0x96, 0xBC])
        let result = try CSVTextDecoder.decode(data)
        #expect(result.encoding == .shiftJIS)
        #expect(result.text == "氏名")
    }

    @Test func rejectsEmptyData() {
        #expect(throws: CSVDecodingError.empty) { try CSVTextDecoder.decode(Data()) }
    }
}

@Suite struct CSVWriterTests {
    @Test func quotesAndGuardsFormulas() {
        let output = CSVWriter.string(from: [["a,b", "say \"hi\"", "=SUM(A1)", "plain"]])
        #expect(output == "\"a,b\",\"say \"\"hi\"\"\",'=SUM(A1),plain\r\n")
    }

    @Test func roundTripsThroughParserAndPlanner() throws {
        let drafts = [RecipientDraft(name: "=危険", jointNames: ["花子", "一郎"], postalCode: "1040061", address1: "東京都中央区見本町1-13-3, 2F")]
        let data = CSVWriter.data(from: CSVTemplate.exportRows(drafts))
        let decoded = try CSVTextDecoder.decode(data)
        let rows = CSVParser.parse(decoded.text)
        let mapping = ColumnMapping.automatic(headers: rows[0])
        let plan = ImportPlanner.plan(rows: rows, hasHeader: true, mapping: mapping, existingKeys: [])
        #expect(plan.count == 1)
        #expect(plan[0].draft == drafts[0])
    }
}
