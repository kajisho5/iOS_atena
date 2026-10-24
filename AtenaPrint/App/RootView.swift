import StoreKit
import SwiftUI

enum AppTab: Hashable {
    case recipients
    case layout
    case settings
}

struct RootView: View {
    @Environment(\.requestReview) private var requestReview
    @State private var selectedTab: AppTab
    @State private var printRequest: PrintRequest?
    private let initialScope: RecipientScope?
    private let initialRecipient: Recipient?

    init(initialTab: AppTab = .recipients, initialScope: RecipientScope? = nil, initialRecipient: Recipient? = nil) {
        _selectedTab = State(initialValue: initialTab)
        self.initialScope = initialScope
        self.initialRecipient = initialRecipient
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            RecipientsRootView(initialScope: initialScope, initialRecipient: initialRecipient)
                .tabItem { Label("tab.recipients", systemImage: "person.2") }
                .tag(AppTab.recipients)
            LayoutSettingsView()
                .tabItem { Label("tab.layout", systemImage: "envelope") }
                .tag(AppTab.layout)
            SettingsView()
                .tabItem { Label("tab.settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .environment(\.printRequestHandler, PrintRequestHandler { printRequest = $0 })
        .fullScreenCover(item: $printRequest, onDismiss: askForReviewIfDue) { request in
            PrintPreviewView(request: request)
        }
    }

    /// Asked once, when the user leaves the preview after more than five successful prints.
    private func askForReviewIfDue() {
        if ReviewPrompter.consumeReviewOpportunity() {
            requestReview()
        }
    }
}
