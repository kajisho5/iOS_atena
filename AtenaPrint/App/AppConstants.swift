import Foundation

/// Values that must be replaced before release. See README "差し替えが必要な定数".
enum AppConstants {
    /// Non-consumable in-app purchase product ID registered in App Store Connect.
    static let proProductID = "com.seventhwell.AtenaPrint.pro"

    /// Public URL of the privacy policy.
    static let privacyPolicyURL = URL(string: "https://example.com/atena-print/privacy")!

    /// Public URL of the terms of use.
    static let termsOfUseURL = URL(string: "https://example.com/atena-print/terms")!

    /// Number of recipients available without Pro.
    static let freeRecipientLimit = 10

    /// Successful print jobs required before asking for a review (asked once, after exceeding this).
    static let reviewRequestThreshold = 5

    /// Maximum CSV size accepted for import, in bytes.
    static let maxCSVImportBytes = 5 * 1024 * 1024

    /// File name of the SwiftData store. Never change after release (it would orphan user data).
    static let storeName = "AtenaPrint"
}
