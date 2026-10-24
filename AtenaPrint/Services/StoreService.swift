import Foundation
import Observation
import StoreKit

/// Owns the Pro (non-consumable) entitlement. Purchase state is never cached on disk;
/// StoreKit's verified transactions are the single source of truth.
@Observable
final class StoreService {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    enum PurchaseOutcome: Equatable {
        case purchased
        case pending
        case cancelled
        case failed
    }

    private(set) var isPro = false
    private(set) var product: Product?
    private(set) var loadState: LoadState = .idle
    private(set) var isPurchasing = false

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await refreshEntitlements() }
    }

    func loadProduct() async {
        guard loadState != .loading else { return }
        loadState = .loading
        do {
            product = try await Product.products(for: [AppConstants.proProductID]).first
            loadState = product == nil ? .failed : .loaded
        } catch {
            loadState = .failed
        }
    }

    func purchase() async -> PurchaseOutcome {
        guard let product else { return .failed }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
                return isPro ? .purchased : .failed
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    /// Re-syncs purchases with the App Store ("購入の復元").
    /// Returns whether Pro is active afterwards.
    func restore() async -> Bool {
        do {
            try await AppStore.sync()
        } catch {
            // Sync can fail when offline or cancelled; fall through to the local entitlement check.
        }
        await refreshEntitlements()
        return isPro
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == AppConstants.proProductID,
               transaction.revocationDate == nil {
                active = true
            }
        }
        isPro = active
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.productID == AppConstants.proProductID {
            await refreshEntitlements()
        }
        await transaction.finish()
    }
}
