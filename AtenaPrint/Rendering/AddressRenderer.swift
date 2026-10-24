import AtenaCore
import CoreGraphics
import CoreText
import Foundation

/// Printer feed compensation in millimeters (+x moves right, +y moves down).
nonisolated struct PrintOffset: Codable, Equatable, Sendable {
    var x: Double = 0
    var y: Double = 0

    static let zero = PrintOffset()
}

nonisolated struct RenderStyle {
    var ink: CGColor
    var showsGuides: Bool
    var guide: CGColor
    var postalFrame: CGColor
    var overflow: CGColor

    /// Output for the printer and PDF: black ink, no guides.
    static var output: RenderStyle {
        RenderStyle(
            ink: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1),
            showsGuides: false,
            guide: CGColor(gray: 0.7, alpha: 1),
            postalFrame: CGColor(srgbRed: 0.88, green: 0.2, blue: 0.17, alpha: 1),
            overflow: CGColor(srgbRed: 0.69, green: 0.29, blue: 0, alpha: 1)
        )
    }
}

/// The single drawing implementation shared by on-screen preview, AirPrint and PDF export.
/// Expects a UIKit-style context (origin at top-left, y grows downwards).
nonisolated struct AddressRenderer: Sendable {
    let font: AddressFont

    static let pointsPerMillimeter: CGFloat = 72 / 25.4

    func draw(_ layout: LayoutResult, in context: CGContext, origin: CGPoint, pointsPerMM: CGFloat,
              offset: PrintOffset = .zero, style: RenderStyle) {
        context.saveGState()
        context.translateBy(x: origin.x + CGFloat(offset.x) * pointsPerMM, y: origin.y + CGFloat(offset.y) * pointsPerMM)
        context.scaleBy(x: pointsPerMM, y: pointsPerMM)

        if style.showsGuides {
            drawPostalFrames(layout.postalFrames, in: context, color: style.postalFrame)
        }
        for run in layout.runs {
            if run.vertical {
                drawVertical(run, in: context, color: style.ink)
            } else {
                drawHorizontal(run, in: context, color: style.ink)
            }
        }
        if style.showsGuides, layout.hasOverflow {
            context.setStrokeColor(style.overflow)
            context.setLineWidth(0.4)
            context.setLineDash(phase: 0, lengths: [1.2, 0.8])
            for run in layout.runs where layout.overflowingRoles.contains(run.role) {
                context.stroke(cgRect(run.frame).insetBy(dx: -0.8, dy: -0.8))
            }
        }
        context.restoreGState()
    }

    // MARK: - Guides

    private func drawPostalFrames(_ frames: [MMRect], in context: CGContext, color: CGColor) {
        context.saveGState()
        context.setStrokeColor(color)
        for (index, frame) in frames.enumerated() {
            // Inner dimensions per specification; the first three boxes use the thicker line.
            let lineWidth: CGFloat = index < 3 ? 0.5 : 0.3
            context.setLineWidth(lineWidth)
            context.stroke(cgRect(frame).insetBy(dx: -lineWidth / 2, dy: -lineWidth / 2))
        }
        // Hyphen between the 3rd and 4th box.
        if frames.count == 7 {
            let y = CGFloat(frames[2].midY)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: frames[2].maxX + 0.25, y: y))
            context.addLine(to: CGPoint(x: frames[3].x - 0.25, y: y))
            context.strokePath()
        }
        context.restoreGState()
    }

    // MARK: - Text

    private func drawHorizontal(_ run: TextRun, in context: CGContext, color: CGColor) {
        let size = CGFloat(run.fontSize)
        let ctFont = font.ctFont(size: size)
        let line = makeLine(run.text, font: ctFont, color: color, tracking: CGFloat(run.tracking))
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let x = run.alignment == .center ? CGFloat(run.frame.midX) - width / 2 : CGFloat(run.frame.x)
        let baseline = CGFloat(run.frame.midY) + (CTFontGetAscent(ctFont) - CTFontGetDescent(ctFont)) / 2
        draw(line, x: x, baseline: baseline, in: context)
    }

    private func drawVertical(_ run: TextRun, in context: CGContext, color: CGColor) {
        let size = CGFloat(run.fontSize)
        let ctFont = font.ctFont(size: size)
        let centerOffset = (CTFontGetAscent(ctFont) - CTFontGetDescent(ctFont)) / 2
        let centerX = CGFloat(run.frame.midX)
        var cellTop = CGFloat(run.frame.y)
        for character in run.text {
            let cell = size * CGFloat(VerticalMetrics.advance(of: character))
            if character == " " {
                cellTop += cell + CGFloat(run.tracking)
                continue
            }
            let line = makeLine(String(character), font: ctFont, color: color, tracking: 0)
            let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            let cellCenterY = cellTop + size / 2
            switch VerticalGlyphs.style(for: character) {
            case .upright:
                draw(line, x: centerX - width / 2, baseline: cellCenterY + centerOffset, in: context)
            case .smallKana:
                draw(line, x: centerX - width / 2 + size * 0.1, baseline: cellCenterY + centerOffset - size * 0.1, in: context)
            case .punctuation:
                draw(line, x: centerX - width / 2 + size * 0.55, baseline: cellCenterY + centerOffset - size * 0.55, in: context)
            case .rotated:
                context.saveGState()
                context.translateBy(x: centerX, y: cellCenterY)
                context.rotate(by: .pi / 2)
                draw(line, x: -width / 2, baseline: centerOffset, in: context)
                context.restoreGState()
            }
            cellTop += cell + CGFloat(run.tracking)
        }
    }

    private func makeLine(_ text: String, font: CTFont, color: CGColor, tracking: CGFloat) -> CTLine {
        var attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ]
        if tracking != 0 {
            attributes[NSAttributedString.Key(kCTKernAttributeName as String)] = tracking
        }
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    }

    /// Draws a line upright in a y-down context.
    private func draw(_ line: CTLine, x: CGFloat, baseline: CGFloat, in context: CGContext) {
        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = CGPoint(x: x, y: baseline)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    private func cgRect(_ rect: MMRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }
}
