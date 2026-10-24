import AtenaCore
import SwiftData
import SwiftUI

/// On-screen sheet: paper outline, postal-code frames and overflow markers are guides only.
struct AddressSheetView: View {
    let layout: LayoutResult
    let font: AddressFont
    let accessibilitySummary: String

    var body: some View {
        let layout = layout
        let font = font
        Canvas { context, size in
            let scale = size.width / CGFloat(layout.paperSize.width)
            context.withCGContext { cgContext in
                AddressRenderer(font: font).draw(layout, in: cgContext, origin: .zero, pointsPerMM: scale, style: .preview)
            }
        }
        .aspectRatio(CGFloat(layout.paperSize.width / layout.paperSize.height), contentMode: .fit)
        .background(Color.paperBackground)
        .overlay {
            Rectangle().strokeBorder(Color.previewGuide, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: accessibilitySummary))
        .accessibilityAddTraits(.isImage)
    }
}

nonisolated extension RenderStyle {
    /// Preview on screen: the paper stays light in dark mode, so fixed colors keep their contrast.
    static var preview: RenderStyle {
        RenderStyle(
            ink: CGColor(srgbRed: 0.1, green: 0.1, blue: 0.1, alpha: 1),
            showsGuides: true,
            guide: CGColor(srgbRed: 0.72, green: 0.72, blue: 0.75, alpha: 1),
            postalFrame: CGColor(srgbRed: 0.88, green: 0.2, blue: 0.17, alpha: 1),
            overflow: CGColor(srgbRed: 0.69, green: 0.29, blue: 0, alpha: 1)
        )
    }
}

/// Sheet preview for a stored recipient using the current layout settings.
struct AddressThumbnail: View {
    let recipient: Recipient
    @Environment(LayoutStore.self) private var layoutStore
    @Query private var senders: [SenderProfile]

    var body: some View {
        let settings = layoutStore.settings
        let content = AddressComposer.content(for: recipient)
        let layout = AddressComposer.layout(content, settings: settings, sender: AddressComposer.sender(settings: settings, profiles: senders))
        VStack(spacing: 8) {
            AddressSheetView(layout: layout, font: settings.font,
                             accessibilitySummary: AddressComposer.accessibilitySummary(content, settings: settings, layout: layout))
                .frame(maxHeight: 280)
            if layout.hasOverflow {
                OverflowWarning()
            }
        }
        .padding(.vertical, 8)
    }
}

struct OverflowWarning: View {
    var body: some View {
        Label("layout.overflow", systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.warningText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.warningFill, in: RoundedRectangle(cornerRadius: 10))
    }
}
