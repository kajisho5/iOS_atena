import SwiftData
import SwiftUI

/// What the content column shows.
enum RecipientScope: Hashable {
    case all
    case unprinted
    case group(RecipientGroup)

    var group: RecipientGroup? {
        if case .group(let group) = self { group } else { nil }
    }
}

/// Recipients tab: sidebar (groups) → list → detail. Collapses to a stack in compact width.
struct RecipientsRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var scope: RecipientScope?
    @State private var selectedRecipient: Recipient?
    @State private var addFlow = RecipientAddFlow()

    init(initialScope: RecipientScope? = nil, initialRecipient: Recipient? = nil) {
        _scope = State(initialValue: initialScope)
        _selectedRecipient = State(initialValue: initialRecipient)
    }

    var body: some View {
        NavigationSplitView {
            GroupSidebarView(selection: $scope)
        } content: {
            if let scope {
                RecipientListView(scope: scope, selection: $selectedRecipient)
            } else {
                ContentUnavailableView("recipients.selectScope", systemImage: "sidebar.left")
            }
        } detail: {
            if let selectedRecipient, selectedRecipient.modelContext != nil {
                RecipientDetailView(recipient: selectedRecipient, group: scope?.group, onDeleted: { self.selectedRecipient = nil })
            } else {
                ContentUnavailableView("recipients.selectRecipient", systemImage: "person.crop.rectangle")
            }
        }
        .environment(addFlow)
        .recipientAddFlow(addFlow)
        .onAppear {
            // In regular width the content column is visible, so start with "all recipients".
            if scope == nil, horizontalSizeClass == .regular {
                scope = .all
            }
        }
    }
}
