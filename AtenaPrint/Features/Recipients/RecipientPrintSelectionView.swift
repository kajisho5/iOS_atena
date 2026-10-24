import SwiftUI

/// Lets the user pick several recipients to print together.
struct RecipientPrintSelectionView: View {
    let recipients: [Recipient]
    let group: RecipientGroup?
    let onConfirm: ([Recipient]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection = Set<Recipient.ID>()

    var body: some View {
        NavigationStack {
            List(recipients, selection: $selection) { recipient in
                RecipientRowView(recipient: recipient, group: group)
            }
            .environment(\.editMode, .constant(.active))
            .safeAreaInset(edge: .bottom) {
                BottomActionBar {
                    Button {
                        let chosen = recipients.filter { selection.contains($0.id) }
                        dismiss()
                        onConfirm(chosen)
                    } label: {
                        Text("print.select.confirm \(selection.count)")
                            .primaryActionLabel()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(selection.isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .navigationTitle(Text("print.select"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(selection.count == recipients.count ? LocalizedStringKey("print.select.none") : LocalizedStringKey("print.select.all")) {
                        if selection.count == recipients.count {
                            selection.removeAll()
                        } else {
                            selection = Set(recipients.map(\.id))
                        }
                    }
                }
            }
        }
    }
}
