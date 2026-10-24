import AtenaCore
import Foundation

/// Builds layout inputs from stored models and settings.
enum AddressComposer {
    static func content(for recipient: Recipient) -> AddressContent {
        AddressContent(name: recipient.name, jointNames: recipient.jointNames, honorific: recipient.honorific,
                       postalCode: recipient.postalCode, address1: recipient.address1, address2: recipient.address2)
    }

    /// Fictional sample shown when there is no recipient yet.
    static var sampleContent: AddressContent {
        AddressContent(name: String(localized: "sample.name"), jointNames: [String(localized: "sample.jointName")],
                       honorific: Honorific.defaultValue, postalCode: "1040061",
                       address1: String(localized: "sample.address1"), address2: String(localized: "sample.address2"))
    }

    /// The sender printed with the current settings, or nil when sender printing is off.
    static func sender(settings: LayoutSettings, profiles: [SenderProfile]) -> SenderProfile? {
        guard settings.printsSender else { return nil }
        let sorted = profiles.sorted { $0.sortOrder < $1.sortOrder }
        return sorted.first { $0.uuid == settings.senderID } ?? sorted.first
    }

    static func options(settings: LayoutSettings, sender: SenderProfile?) -> LayoutOptions {
        LayoutOptions(paper: settings.paper, writingMode: settings.writingMode,
                      convertDigitsToKanji: settings.convertDigitsToKanji, sender: sender?.content)
    }

    static func layout(_ content: AddressContent, settings: LayoutSettings, sender: SenderProfile?) -> LayoutResult {
        AddressLayoutEngine(measurer: CoreTextMeasurer(font: settings.font))
            .layout(content, options: options(settings: settings, sender: sender))
    }

    /// VoiceOver summary of a sheet.
    static func accessibilitySummary(_ content: AddressContent, settings: LayoutSettings, layout: LayoutResult) -> String {
        let names = ([content.name] + content.jointNames).filter { !$0.isEmpty }.map { "\($0) \(content.honorific)" }.joined(separator: "、")
        let postal = content.postalCode.isEmpty ? "" : "〒" + PostalCode.formatted(content.postalCode)
        let address = [postal, content.address1, content.address2].filter { !$0.isEmpty }.joined(separator: " ")
        var summary = String(localized: "a11y.sheet \(settings.paper.localizedName) \(settings.writingMode.localizedName) \(address) \(names)")
        if layout.hasOverflow {
            summary += " " + String(localized: "a11y.sheet.overflow")
        }
        return summary
    }
}

extension PaperKind {
    var localizedName: String {
        switch self {
        case .hagaki: String(localized: "paper.hagaki")
        case .nagagata3: String(localized: "paper.nagagata3")
        case .nagagata4: String(localized: "paper.nagagata4")
        case .yougata2: String(localized: "paper.yougata2")
        case .kakugata2: String(localized: "paper.kakugata2")
        }
    }

    /// e.g. "100×148mm"
    var dimensionText: String {
        "\(Int(size.width))×\(Int(size.height))mm"
    }
}

extension WritingMode {
    var localizedName: String {
        switch self {
        case .vertical: String(localized: "writing.vertical")
        case .horizontal: String(localized: "writing.horizontal")
        }
    }
}
