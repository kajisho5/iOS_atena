import AtenaCore
import Foundation
import Testing
import UIKit
@testable import AtenaPrint

/// Renders sheets with the real fonts and writes PNG files when SNAPSHOT_DIR is set
/// (CI passes TEST_RUNNER_SNAPSHOT_DIR). Always checks that rendering produces ink.
@MainActor
@Suite struct RenderingSnapshotTests {
    let content = AddressContent(name: "山田 太郎", jointNames: ["花子"], honorific: "様", postalCode: "1040061",
                                 address1: "東京都中央区見本町1-13-3", address2: "サンプルハイツ203")
    let sender = SenderContent(name: "田中 一郎", postalCode: "1230045", address1: "東京都見本区見本町2-5")

    @Test(arguments: PaperKind.allCases, WritingMode.allCases)
    func rendersSheet(paper: PaperKind, mode: WritingMode) throws {
        var settings = LayoutSettings()
        settings.paper = paper
        settings.writingMode = mode
        let layout = AddressLayoutEngine(measurer: CoreTextMeasurer(font: settings.font))
            .layout(content, options: LayoutOptions(paper: paper, writingMode: mode, convertDigitsToKanji: true, sender: sender))
        #expect(!layout.hasOverflow, "\(layout.overflowingRoles)")

        let scale: CGFloat = 6
        let size = CGSize(width: paper.size.width * scale, height: paper.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            AddressRenderer(font: settings.font).draw(layout, in: context.cgContext, origin: .zero, pointsPerMM: scale, style: .preview)
        }
        let png = try #require(image.pngData())
        #expect(png.count > 5_000)
        if let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("sheet-\(paper.rawValue)-\(mode.rawValue).png"))
        }
    }

    @Test func pdfHasOnePagePerSheet() throws {
        let layout = AddressLayoutEngine(measurer: CoreTextMeasurer(font: .mincho)).layout(content, options: LayoutOptions())
        let data = PDFExporter.makePDF(pages: [layout, layout, layout], font: .mincho, paper: .hagaki, title: "test")
        let document = try #require(CGPDFDocument(CGDataProvider(data: data as CFData)!))
        #expect(document.numberOfPages == 3)
        let box = try #require(document.page(at: 1)?.getBoxRect(.mediaBox))
        #expect(abs(box.width - 100 * 72 / 25.4) < 0.5)
        #expect(abs(box.height - 148 * 72 / 25.4) < 0.5)
    }
}
