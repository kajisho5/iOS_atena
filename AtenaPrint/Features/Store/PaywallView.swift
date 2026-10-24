import StoreKit
import SwiftUI

enum PaywallReason: String {
    case recipientLimit
    case csvImport
    case pdfExport
    case settings
}

/// Pro purchase sheet (S13). Shown only when the user explicitly opens it.
struct PaywallView: View {
    let reason: PaywallReason

    @Environment(\.dismiss) private var dismiss
    @Environment(StoreService.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var message: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    if let context = contextMessage {
                        Text(context)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    features
                    promises
                    if dynamicTypeSize.isAccessibilitySize {
                        // At accessibility sizes a pinned bar would cover most of the screen.
                        purchaseArea
                    }
                    if store.isPro {
                        Label("store.owned", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(Color.successText)
                    }
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                if !dynamicTypeSize.isAccessibilitySize {
                    purchaseArea
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background {
                            Color(.systemGroupedBackground)
                                .overlay(alignment: .top) { Divider() }
                                .ignoresSafeArea()
                        }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("common.close", systemImage: "xmark")
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
            .task {
                if store.product == nil {
                    await store.loadProduct()
                }
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("common.ok", role: .cancel) {
                    if store.isPro { dismiss() }
                }
            }
        }
    }

    private var contextMessage: LocalizedStringKey? {
        switch reason {
        case .recipientLimit: "store.context.limit \(AppConstants.freeRecipientLimit)"
        case .csvImport: "store.context.csv \(AppConstants.freeRecipientLimit)"
        case .pdfExport: "store.context.pdf"
        case .settings: nil
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityHidden(true)
            Text("store.title")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text("store.subtitle")
                .font(.body)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(systemImage: "person.2.fill", title: "store.feature.unlimited", detail: "store.feature.unlimited.detail \(AppConstants.freeRecipientLimit)")
            FeatureRow(systemImage: "doc.text.fill", title: "store.feature.csv", detail: "store.feature.csv.detail \(AppConstants.freeRecipientLimit)")
            FeatureRow(systemImage: "square.and.arrow.up.fill", title: "store.feature.pdf", detail: "store.feature.pdf.detail")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var promises: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("store.promise.oneTime").fontWeight(.semibold)
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.successText)
            }
            Label {
                Text("store.promise.noAds").fontWeight(.semibold)
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.successText)
            }
            Label {
                Text("store.promise.freePrinting")
                    .foregroundStyle(Color.secondaryText)
            } icon: {
                Image(systemName: "info.circle").foregroundStyle(Color.secondaryText)
            }
        }
        .font(.subheadline)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var purchaseArea: some View {
        VStack(spacing: 12) {
            if store.isPro {
                EmptyView()
            } else if let product = store.product {
                Button {
                    purchase()
                } label: {
                    Group {
                        if store.isPurchasing {
                            ProgressView()
                        } else {
                            // The price is shown exactly as the App Store reports it.
                            Text("store.buy \(product.displayPrice)")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isPurchasing)
            } else if store.loadState == .failed {
                VStack(spacing: 8) {
                    Text("store.loadFailed")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("common.retry") {
                        Task { await store.loadProduct() }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                ProgressView()
                    .frame(minHeight: 44)
            }
            Button("store.restore") { restore() }
                .frame(minHeight: 44)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    Link("settings.terms", destination: AppConstants.termsOfUseURL)
                    Link("settings.privacy", destination: AppConstants.privacyPolicyURL)
                }
                VStack(spacing: 8) {
                    Link("settings.terms", destination: AppConstants.termsOfUseURL)
                    Link("settings.privacy", destination: AppConstants.privacyPolicyURL)
                }
            }
            .font(.footnote)
        }
        .frame(maxWidth: 560)
    }

    private func purchase() {
        Task {
            switch await store.purchase() {
            case .purchased: message = "store.purchase.success"
            case .pending: message = "store.purchase.pending"
            case .cancelled: break
            case .failed: message = "store.purchase.failed"
            }
        }
    }

    private func restore() {
        Task {
            message = await store.restore() ? "store.restore.success" : "store.restore.none"
        }
    }
}

private struct FeatureRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(Color.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
