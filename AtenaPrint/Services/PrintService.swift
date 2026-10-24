import AtenaCore
import UIKit

/// Sends laid-out sheets to AirPrint.
final class PrintService: NSObject, UIPrintInteractionControllerDelegate {
    private let paper: PaperKind
    private var retainedSelf: PrintService?

    private init(paper: PaperKind) {
        self.paper = paper
    }

    /// Presents the system print UI. `completion` receives true when the job was handed to the printer.
    static func startPrinting(pages: [LayoutResult], font: AddressFont, paper: PaperKind, offset: PrintOffset,
                      showsPostalFrames: Bool = false, jobName: String, completion: @escaping (Bool) -> Void) {
        guard !pages.isEmpty, UIPrintInteractionController.isPrintingAvailable else {
            completion(false)
            return
        }
        let service = PrintService(paper: paper)
        service.retainedSelf = service

        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.orientation = .portrait
        printInfo.jobName = jobName
        printInfo.duplex = .none

        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.delegate = service
        controller.printPageRenderer = AddressPageRenderer(pages: pages, font: font, offset: offset, showsPostalFrames: showsPostalFrames)
        controller.present(animated: true) { _, completed, _ in
            controller.printPageRenderer = nil
            controller.delegate = nil
            service.retainedSelf = nil
            completion(completed)
        }
    }

    // Pick the printer paper closest to the sheet size (e.g. "Postcard" for はがき).
    func printInteractionController(_ printInteractionController: UIPrintInteractionController, choosePaper paperList: [UIPrintPaper]) -> UIPrintPaper {
        let size = CGSize(width: paper.size.width * AddressRenderer.pointsPerMillimeter,
                          height: paper.size.height * AddressRenderer.pointsPerMillimeter)
        return UIPrintPaper.bestPaper(forPageSize: size, withPapersFrom: paperList)
    }
}

/// `UIPrintPageRenderer` is not main-actor isolated; the printing system calls it on its own schedule.
nonisolated final class AddressPageRenderer: UIPrintPageRenderer {
    private let pages: [LayoutResult]
    private let font: AddressFont
    private let offset: PrintOffset
    private let showsPostalFrames: Bool

    init(pages: [LayoutResult], font: AddressFont, offset: PrintOffset, showsPostalFrames: Bool) {
        self.pages = pages
        self.font = font
        self.offset = offset
        self.showsPostalFrames = showsPostalFrames
        super.init()
    }

    override var numberOfPages: Int {
        pages.count
    }

    override func drawPage(at pageIndex: Int, in printableRect: CGRect) {
        guard pages.indices.contains(pageIndex), let context = UIGraphicsGetCurrentContext() else { return }
        var style = RenderStyle.output
        if showsPostalFrames {
            style.showsGuides = true
            style.postalFrame = CGColor(gray: 0, alpha: 1)
        }
        AddressRenderer(font: font).draw(pages[pageIndex], in: context, origin: paperRect.origin,
                                         pointsPerMM: AddressRenderer.pointsPerMillimeter, offset: offset, style: style)
    }
}

enum PDFExporter {
    /// One page per sheet at actual size. Printer offsets are not applied (they are printer specific).
    static func makePDF(pages: [LayoutResult], font: AddressFont, paper: PaperKind, title: String) -> Data {
        let bounds = CGRect(x: 0, y: 0,
                            width: paper.size.width * AddressRenderer.pointsPerMillimeter,
                            height: paper.size.height * AddressRenderer.pointsPerMillimeter)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: title]
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        return renderer.pdfData { context in
            for page in pages {
                context.beginPage()
                AddressRenderer(font: font).draw(page, in: context.cgContext, origin: .zero,
                                                 pointsPerMM: AddressRenderer.pointsPerMillimeter, style: .output)
            }
        }
    }

    /// Writes the PDF to a temporary file for sharing.
    static func writeTemporaryFile(_ data: Data, fileName: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PDFExport", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(safeFileName(fileName))
        try data.write(to: url, options: .atomic)
        return url
    }

    /// A group name such as "2026/年賀状" must not become a path: replace path separators and
    /// characters that are not allowed in file names.
    static func safeFileName(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:").union(.newlines).union(.controlCharacters)
        let cleaned = String(name.unicodeScalars.map { forbidden.contains($0) ? "-" : Character($0) })
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty || cleaned.hasPrefix(".") ? "AtenaPrint" + cleaned : cleaned
    }
}

/// Counts successful print jobs and asks for a review once, after the threshold is exceeded.
enum ReviewPrompter {
    private static let countKey = "review.successfulPrintCount"
    private static let requestedKey = "review.requested"

    static func recordSuccessfulPrint(defaults: UserDefaults = .standard) {
        defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
    }

    /// Returns true at most once in the app's lifetime.
    static func consumeReviewOpportunity(defaults: UserDefaults = .standard) -> Bool {
        guard !defaults.bool(forKey: requestedKey),
              defaults.integer(forKey: countKey) > AppConstants.reviewRequestThreshold else { return false }
        defaults.set(true, forKey: requestedKey)
        return true
    }
}
