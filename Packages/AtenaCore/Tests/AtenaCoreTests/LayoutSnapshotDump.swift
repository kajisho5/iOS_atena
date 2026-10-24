import Foundation
import Testing
@testable import AtenaCore

/// Writes SVG renderings of the layouts when ATENA_LAYOUT_SVG_DIR is set (manual visual check).
@Suite struct LayoutSnapshotDump {
    @Test func dumpSVG() throws {
        guard let directory = ProcessInfo.processInfo.environment["ATENA_LAYOUT_SVG_DIR"] else { return }
        let engine = AddressLayoutEngine(measurer: FixedWidthMeasurer())
        let content = AddressContent(name: "山田 太郎", jointNames: ["花子"], honorific: "様", postalCode: "104-0061",
                                     address1: "東京都中央区見本町1-13-3", address2: "サンプルハイツ203")
        let sender = SenderContent(name: "田中 一郎", postalCode: "1230045", address1: "東京都見本区見本町2-5")
        for paper in PaperKind.allCases {
            for mode in WritingMode.allCases {
                let result = engine.layout(content, options: LayoutOptions(paper: paper, writingMode: mode, sender: sender))
                var svg = "<svg xmlns='http://www.w3.org/2000/svg' width='\(paper.size.width * 4)' height='\(paper.size.height * 4)' viewBox='0 0 \(paper.size.width) \(paper.size.height)'>"
                svg += "<rect width='100%' height='100%' fill='white' stroke='#999' stroke-width='0.3'/>"
                for box in result.postalFrames {
                    svg += "<rect x='\(box.x)' y='\(box.y)' width='\(box.width)' height='\(box.height)' fill='none' stroke='red' stroke-width='0.3'/>"
                }
                for run in result.runs {
                    svg += "<rect x='\(run.frame.x)' y='\(run.frame.y)' width='\(run.frame.width)' height='\(run.frame.height)' fill='none' stroke='#0a0' stroke-width='0.15'/>"
                    if run.vertical {
                        svg += "<text x='\(run.frame.midX)' y='\(run.frame.y)' font-size='\(run.fontSize)' letter-spacing='\(run.tracking)' font-family='IPAMincho' style='writing-mode: vertical-rl'>\(run.text)</text>"
                    } else {
                        let x = run.alignment == .center ? run.frame.midX : run.frame.x
                        let anchor = run.alignment == .center ? "middle" : "start"
                        svg += "<text x='\(x)' y='\(run.frame.y + run.frame.height * 0.85)' font-size='\(run.fontSize)' letter-spacing='\(run.tracking)' text-anchor='\(anchor)' font-family='IPAMincho'>\(run.text)</text>"
                    }
                }
                svg += "</svg>"
                try svg.write(toFile: "\(directory)/\(paper.rawValue)-\(mode.rawValue).svg", atomically: true, encoding: .utf8)
            }
        }
    }
}
