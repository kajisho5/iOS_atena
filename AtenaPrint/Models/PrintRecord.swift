import Foundation
import SwiftData

/// One recipient sent to the printer (or exported). "Printed" means the job was handed to the
/// print system successfully; iOS does not report whether the sheet actually came out.
@Model
final class PrintRecord {
    var recipient: Recipient?
    var group: RecipientGroup?
    /// `PaperKind.rawValue`.
    var paperKind: String = ""
    var printedAt: Date = Date()

    init(recipient: Recipient, group: RecipientGroup?, paperKind: String, printedAt: Date = Date()) {
        self.recipient = recipient
        self.group = group
        self.paperKind = paperKind
        self.printedAt = printedAt
    }
}
