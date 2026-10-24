import SwiftUI

/// Shown when the data store cannot be opened. The store file is never deleted automatically,
/// so the user's data stays on the device and can be recovered by an update.
struct DataStoreErrorView: View {
    let error: any Error

    var body: some View {
        ContentUnavailableView {
            Label("store.error.title", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            VStack(spacing: 12) {
                Text("store.error.message")
                Text(verbatim: String(describing: error))
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
                    .textSelection(.enabled)
            }
        }
    }
}
