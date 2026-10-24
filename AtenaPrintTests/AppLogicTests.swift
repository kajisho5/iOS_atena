import AtenaCore
import CoreText
import Foundation
import SwiftData
import Testing
@testable import AtenaPrint

@MainActor
@Suite struct AppLogicTests {
    @Test func freeLimitMatchesCore() {
        #expect(AppConstants.freeRecipientLimit == FreeTier.recipientLimit)
    }

    @Test func printedStateIsScopedToGroup() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let groupA = RecipientGroup(name: "A", sortOrder: 0)
        let groupB = RecipientGroup(name: "B", sortOrder: 1)
        let recipient = Recipient(draft: RecipientDraft(name: "山田 太郎", nameKana: "やまだ たろう", postalCode: "104-0061", address1: "東京都"))
        context.insert(groupA)
        context.insert(groupB)
        context.insert(recipient)
        recipient.groups = [groupA, groupB]
        context.insert(PrintRecord(recipient: recipient, group: groupA, paperKind: PaperKind.hagaki.rawValue))
        try context.save()

        #expect(recipient.postalCode == "1040061")
        #expect(recipient.sortKey == "やまだたろう")
        #expect(recipient.isPrinted())
        #expect(recipient.isPrinted(in: groupA))
        #expect(!recipient.isPrinted(in: groupB))
    }

    @Test func deletingRecipientRemovesPrintRecords() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let recipient = Recipient(draft: RecipientDraft(name: "佐藤"))
        context.insert(recipient)
        context.insert(PrintRecord(recipient: recipient, group: nil, paperKind: PaperKind.hagaki.rawValue))
        try context.save()
        context.delete(recipient)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<PrintRecord>()) == 0)
    }

    @Test func layoutSettingsDecodeToleratesMissingKeys() throws {
        let data = Data(#"{"paper":"nagagata3","unknownKey":1}"#.utf8)
        let settings = try JSONDecoder().decode(LayoutSettings.self, from: data)
        #expect(settings.paper == .nagagata3)
        #expect(settings.writingMode == .vertical)
        #expect(settings.offset(for: .hagaki) == .zero)
    }

    @Test func bundledFontsAreAvailable() {
        for font in AddressFont.allCases {
            let ctFont = font.ctFont(size: 12)
            #expect(CTFontCopyPostScriptName(ctFont) as String == font.postScriptName, "\(font) missing on this OS")
        }
    }

    @Test func reviewIsRequestedOnlyOnceAfterThreshold() throws {
        let defaults = try #require(UserDefaults(suiteName: "ReviewPrompterTests-\(UUID().uuidString)"))
        for _ in 0..<AppConstants.reviewRequestThreshold {
            ReviewPrompter.recordSuccessfulPrint(defaults: defaults)
        }
        #expect(!ReviewPrompter.consumeReviewOpportunity(defaults: defaults))
        ReviewPrompter.recordSuccessfulPrint(defaults: defaults)
        #expect(ReviewPrompter.consumeReviewOpportunity(defaults: defaults))
        ReviewPrompter.recordSuccessfulPrint(defaults: defaults)
        #expect(!ReviewPrompter.consumeReviewOpportunity(defaults: defaults))
    }
}
