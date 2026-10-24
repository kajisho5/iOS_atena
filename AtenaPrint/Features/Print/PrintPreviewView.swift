import AtenaCore
import SwiftData
import SwiftUI

/// Print preview (S07). Regular width: sheet on the left, side panel on the right.
/// Compact width: sheet on top, controls at the bottom. The whole sheet is always visible.
struct PrintPreviewView: View {
    let request: PrintRequest

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Environment(LayoutStore.self) private var layoutStore
    @Environment(StoreService.self) private var store
    @Query(sort: \SenderProfile.sortOrder) private var senders: [SenderProfile]

    @State private var pageIndex = 0
    @State private var zoom: CGFloat = 1
    @State private var committedZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var committedPan: CGSize = .zero
    @State private var isPrinting = false
    @State private var isShowingPaywall = false
    @State private var exportedPDF: ExportedFile?
    @State private var resultMessage: LocalizedStringKey?

    private struct Page {
        let content: AddressContent
        let recipient: Recipient?
        let layout: LayoutResult
        let lastPrinted: Date?
    }

    private var settings: LayoutSettings {
        var settings = layoutStore.settings
        if case .test(let paper) = request.kind {
            settings.paper = paper
        }
        return settings
    }

    private var group: RecipientGroup? {
        if case .recipients(_, let group) = request.kind { group } else { nil }
    }

    private var isTest: Bool {
        if case .test = request.kind { true } else { false }
    }

    private var pages: [Page] {
        let settings = settings
        let sender = AddressComposer.sender(settings: settings, profiles: senders)
        switch request.kind {
        case .recipients(let recipients, let group):
            return recipients.filter { $0.modelContext != nil }.map { recipient in
                let content = AddressComposer.content(for: recipient)
                return Page(content: content, recipient: recipient,
                            layout: AddressComposer.layout(content, settings: settings, sender: sender),
                            lastPrinted: recipient.lastPrint(in: group)?.printedAt)
            }
        case .test:
            let content = AddressComposer.sampleContent
            return [Page(content: content, recipient: nil, layout: AddressComposer.layout(content, settings: settings, sender: sender), lastPrinted: nil)]
        }
    }

    var body: some View {
        let pages = pages
        let index = min(pageIndex, max(pages.count - 1, 0))
        NavigationStack {
            Group {
                if pages.isEmpty {
                    ContentUnavailableView("print.empty", systemImage: "doc")
                } else if horizontalSizeClass == .regular {
                    HStack(spacing: 0) {
                        sheetArea(pages[index])
                        Divider()
                        ScrollView {
                            sidePanel(pages: pages, index: index)
                                .padding(20)
                        }
                        .frame(width: 320)
                        .background(Color(.systemGroupedBackground))
                    }
                } else if dynamicTypeSize.isAccessibilitySize {
                    // Large text: scroll everything and keep the sheet at a readable height.
                    ScrollView {
                        VStack(spacing: 16) {
                            warnings(pages[index])
                            sheetArea(pages[index])
                                .frame(height: 460)
                            pageControls(count: pages.count, index: index)
                            actionButtons(pages: pages)
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 0) {
                        warnings(pages[index])
                            .padding(.horizontal)
                            .padding(.top, 8)
                        sheetArea(pages[index])
                        pageControls(count: pages.count, index: index)
                            .padding(.bottom, 8)
                    }
                    .safeAreaInset(edge: .bottom) {
                        actionButtons(pages: pages)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
                }
            }
            .background(Color.previewBackground)
            .navigationTitle(Text("print.preview.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("common.close", systemImage: "xmark")
                    }
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("print.preview.title").font(.headline)
                        Text(verbatim: settings.paper.localizedName + " ・ " + settings.writingMode.localizedName)
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView(reason: .pdfExport)
            }
            .sheet(item: $exportedPDF) { file in
                ActivityView(items: [file.url])
                    .ignoresSafeArea()
            }
            .alert(resultMessage ?? "", isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })) {
                Button("common.ok", role: .cancel) {}
            }
            .onChange(of: pageIndex) { resetZoom() }
        }
    }

    // MARK: - Sheet

    private func sheetArea(_ page: Page) -> some View {
        AddressSheetView(layout: page.layout, font: settings.font,
                         accessibilitySummary: AddressComposer.accessibilitySummary(page.content, settings: settings, layout: page.layout))
            .scaleEffect(zoom)
            .offset(pan)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .clipped()
            .gesture(
                MagnifyGesture()
                    .onChanged { value in zoom = min(max(committedZoom * value.magnification, 1), 4) }
                    .onEnded { _ in committedZoom = zoom }
                    .simultaneously(with: DragGesture()
                        .onChanged { value in
                            guard zoom > 1 else { return }
                            pan = CGSize(width: committedPan.width + value.translation.width, height: committedPan.height + value.translation.height)
                        }
                        .onEnded { _ in committedPan = pan })
            )
            .onTapGesture(count: 2) { withAnimation { resetZoom() } }
            .accessibilityAction(named: Text("print.zoom.reset")) { resetZoom() }
    }

    private func resetZoom() {
        zoom = 1
        committedZoom = 1
        pan = .zero
        committedPan = .zero
    }

    // MARK: - Panels

    @ViewBuilder
    private func warnings(_ page: Page) -> some View {
        VStack(spacing: 8) {
            if let lastPrinted = page.lastPrinted {
                let date = lastPrinted.formatted(date: .abbreviated, time: .omitted)
                WarningBanner(systemImage: "exclamationmark.triangle.fill", title: Text("print.warning.printed \(date)"))
            }
            if page.layout.hasOverflow {
                WarningBanner(systemImage: "exclamationmark.triangle.fill", title: Text("layout.overflow"))
            }
        }
    }

    private func pageControls(count: Int, index: Int) -> some View {
        HStack(spacing: 24) {
            Button {
                pageIndex = max(index - 1, 0)
            } label: {
                Label("print.page.previous", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(index == 0)
            .keyboardShortcut(.leftArrow, modifiers: [])
            Text("print.page \(index + 1) \(count)")
                .font(.headline)
                .monospacedDigit()
            Button {
                pageIndex = min(index + 1, count - 1)
            } label: {
                Label("print.page.next", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(index >= count - 1)
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .accessibilityElement(children: .contain)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: pageIndex = min(index + 1, count - 1)
            case .decrement: pageIndex = max(index - 1, 0)
            @unknown default: break
            }
        }
    }

    private func sidePanel(pages: [Page], index: Int) -> some View {
        let page = pages[index]
        return VStack(alignment: .leading, spacing: 16) {
            pageControls(count: pages.count, index: index)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: ([page.content.name] + page.content.jointNames).filter { !$0.isEmpty }.map { $0 + " " + page.content.honorific }.joined(separator: "・"))
                    .font(.headline)
                Text(verbatim: "〒" + PostalCode.formatted(page.content.postalCode) + " " + page.content.address1)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            }
            warnings(page)
            VStack(alignment: .leading, spacing: 4) {
                Text("layout.paper").font(.caption.weight(.semibold)).foregroundStyle(Color.secondaryText)
                Text(verbatim: settings.paper.localizedName + "（" + settings.paper.dimensionText + "）")
                let offset = settings.offset(for: settings.paper)
                if offset != .zero {
                    let vertical = offset.y.formatted(.number.precision(.fractionLength(1)))
                    let horizontal = offset.x.formatted(.number.precision(.fractionLength(1)))
                    Text("print.offsetApplied \(vertical) \(horizontal)")
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            actionButtons(pages: pages)
        }
    }

    private func actionButtons(pages: [Page]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                pdfButton(pages: pages)
                printButton(pages: pages)
            }
            VStack(spacing: 12) {
                printButton(pages: pages)
                pdfButton(pages: pages)
            }
        }
    }

    private func printButton(pages: [Page]) -> some View {
        Button {
            startPrinting(pages: pages)
        } label: {
            Label(isTest ? LocalizedStringKey("offset.testPrint") : LocalizedStringKey("print.action \(pages.count)"), systemImage: "printer")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isPrinting || pages.isEmpty)
        .keyboardShortcut("p", modifiers: .command)
        .hoverEffect()
    }

    @ViewBuilder
    private func pdfButton(pages: [Page]) -> some View {
        if !isTest {
            Button {
                exportPDF(pages: pages)
            } label: {
                Label(store.isPro ? LocalizedStringKey("print.pdf") : LocalizedStringKey("print.pdf.pro"), systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut("e", modifiers: .command)
            .hoverEffect()
        }
    }

    // MARK: - Actions

    private func startPrinting(pages: [Page]) {
        isPrinting = true
        let settings = settings
        let jobTitle = group?.name ?? String(localized: "app.name")
        let jobName = isTest ? String(localized: "offset.testPrint") : String(localized: "print.jobName \(jobTitle)")
        PrintService.startPrinting(pages: pages.map(\.layout), font: settings.font, paper: settings.paper,
                                   offset: settings.offset(for: settings.paper), showsPostalFrames: isTest, jobName: jobName) { completed in
            isPrinting = false
            guard completed else { return }
            ReviewPrompter.recordSuccessfulPrint()
            guard !isTest else { return }
            let now = Date()
            for page in pages {
                if let recipient = page.recipient, recipient.modelContext != nil {
                    modelContext.insert(PrintRecord(recipient: recipient, group: group, paperKind: settings.paper.rawValue, printedAt: now))
                }
            }
            try? modelContext.save()
            resultMessage = "print.result.sent"
        }
    }

    private func exportPDF(pages: [Page]) {
        guard store.isPro else {
            isShowingPaywall = true
            return
        }
        let settings = settings
        let title = group?.name ?? String(localized: "app.name")
        let data = PDFExporter.makePDF(pages: pages.map(\.layout), font: settings.font, paper: settings.paper, title: title)
        do {
            let url = try PDFExporter.writeTemporaryFile(data, fileName: String(localized: "print.pdf.fileName \(title)"))
            exportedPDF = ExportedFile(url: url)
        } catch {
            resultMessage = "print.pdf.failed"
        }
    }
}

struct ExportedFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct WarningBanner: View {
    let systemImage: String
    let title: Text

    var body: some View {
        Label {
            title.fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.subheadline)
        .foregroundStyle(Color.warningText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.warningFill, in: RoundedRectangle(cornerRadius: 12))
    }
}
