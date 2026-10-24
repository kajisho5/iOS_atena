import AtenaCore
import Foundation
import SwiftData

@Model
final class Recipient {
    var name: String = ""
    var nameKana: String = ""
    var jointNames: [String] = []
    var honorific: String = Honorific.defaultValue
    /// Digits only (7 digits when valid).
    var postalCode: String = ""
    var address1: String = ""
    var address2: String = ""
    var memo: String = ""
    /// Sort key: reading when available, otherwise the name.
    var sortKey: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(inverse: \RecipientGroup.recipients)
    var groups: [RecipientGroup] = []

    @Relationship(deleteRule: .cascade, inverse: \PrintRecord.recipient)
    var printRecords: [PrintRecord] = []

    init(draft: RecipientDraft) {
        apply(draft)
    }

    func apply(_ draft: RecipientDraft) {
        name = TextNormalization.trimmed(draft.name)
        nameKana = TextNormalization.trimmed(draft.nameKana)
        jointNames = draft.jointNames.map(TextNormalization.trimmed).filter { !$0.isEmpty }
        let trimmedHonorific = TextNormalization.trimmed(draft.honorific)
        honorific = trimmedHonorific.isEmpty ? Honorific.defaultValue : trimmedHonorific
        postalCode = PostalCode.digitsOnly(draft.postalCode)
        address1 = TextNormalization.trimmed(draft.address1)
        address2 = TextNormalization.trimmed(draft.address2)
        memo = TextNormalization.trimmed(draft.memo)
        sortKey = nameKana.isEmpty ? TextNormalization.removingSpaces(name) : TextNormalization.removingSpaces(nameKana)
        updatedAt = Date()
    }

    var draft: RecipientDraft {
        RecipientDraft(name: name, nameKana: nameKana, jointNames: jointNames, honorific: honorific,
                       postalCode: postalCode, address1: address1, address2: address2, memo: memo)
    }

    var duplicateKey: String { DuplicateKey.make(name: name, postalCode: postalCode) }

    var hasValidPostalCode: Bool { PostalCode.normalize(postalCode) != nil }

    /// Most recent print record, optionally limited to a group.
    func lastPrint(in group: RecipientGroup? = nil) -> PrintRecord? {
        printRecords
            .filter { record in
                guard let group else { return true }
                return record.group?.persistentModelID == group.persistentModelID
            }
            .max(by: { $0.printedAt < $1.printedAt })
    }

    func isPrinted(in group: RecipientGroup? = nil) -> Bool {
        lastPrint(in: group) != nil
    }
}
