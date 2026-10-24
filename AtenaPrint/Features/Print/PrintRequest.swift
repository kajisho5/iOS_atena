import AtenaCore
import SwiftUI

/// What the user asked to print.
struct PrintRequest: Identifiable {
    enum Kind {
        case recipients([Recipient], group: RecipientGroup?)
        /// Alignment test sheet: sample address plus the postal-code frames.
        case test(PaperKind)
    }

    let id = UUID()
    let kind: Kind

    init(recipients: [Recipient], group: RecipientGroup?) {
        kind = .recipients(recipients, group: group)
    }

    init(test paper: PaperKind) {
        kind = .test(paper)
    }
}

struct PrintRequestHandler {
    let action: (PrintRequest) -> Void

    func callAsFunction(_ request: PrintRequest) {
        action(request)
    }
}

extension EnvironmentValues {
    @Entry var printRequestHandler = PrintRequestHandler { _ in }
}
