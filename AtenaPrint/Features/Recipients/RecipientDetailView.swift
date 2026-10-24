import AtenaCore
import SwiftData
import SwiftUI

struct RecipientDetailView: View {
    @Bindable var recipient: Recipient
    let group: RecipientGroup?
    let onDeleted: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.printRequestHandler) private var requestPrint
    @Environment(RecipientAddFlow.self) private var addFlow
    @State private var isConfirmingDeletion = false

    private var sortedRecords: [PrintRecord] {
        recipient.printRecords.sorted { $0.printedAt > $1.printedAt }
    }

    var body: some View {
        List {
            Section {
                AddressThumbnail(recipient: recipient)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
            Section("detail.address") {
                if !recipient.postalCode.isEmpty {
                    LabeledContent("editor.postalCode") {
                        Text(verbatim: "〒" + PostalCode.formatted(recipient.postalCode))
                    }
                }
                LabeledContent("editor.address1") { Text(verbatim: recipient.address1) }
                if !recipient.address2.isEmpty {
                    LabeledContent("editor.address2") { Text(verbatim: recipient.address2) }
                }
            }
            if !recipient.jointNames.isEmpty || !recipient.memo.isEmpty || !recipient.groups.isEmpty {
                Section("detail.other") {
                    if !recipient.jointNames.isEmpty {
                        LabeledContent("editor.jointNames") {
                            Text(verbatim: recipient.jointNames.map { $0 + " " + recipient.honorific }.joined(separator: "、"))
                        }
                    }
                    if !recipient.groups.isEmpty {
                        LabeledContent("editor.groups") {
                            Text(verbatim: recipient.groups.sorted { $0.sortOrder < $1.sortOrder }.map(\.name).joined(separator: "、"))
                        }
                    }
                    if !recipient.memo.isEmpty {
                        LabeledContent("editor.memo") { Text(verbatim: recipient.memo) }
                    }
                }
            }
            Section("detail.history") {
                if sortedRecords.isEmpty {
                    Text("detail.history.empty")
                        .foregroundStyle(Color.secondaryText)
                } else {
                    ForEach(sortedRecords) { record in
                        LabeledContent {
                            Text(verbatim: record.group?.name ?? "")
                        } label: {
                            Label {
                                Text(verbatim: record.printedAt.formatted(date: .numeric, time: .shortened) + "  " + (PaperKind(rawValue: record.paperKind)?.localizedName ?? ""))
                            } icon: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.successText)
                            }
                        }
                    }
                    .onDelete(perform: deleteRecords)
                }
            }
            Section {
                Button {
                    requestPrint(PrintRequest(recipients: [recipient], group: group))
                } label: {
                    Label("recipients.printThis", systemImage: "printer")
                }
                Button("recipients.delete.confirm", role: .destructive) {
                    isConfirmingDeletion = true
                }
            }
        }
        .navigationTitle(Text(verbatim: recipient.name + " " + recipient.honorific))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("common.edit") { addFlow.sheet = .editRecipient(recipient) }
            }
        }
        .confirmationDialog("recipients.delete.title", isPresented: $isConfirmingDeletion, titleVisibility: .visible) {
            Button("recipients.delete.confirm", role: .destructive) {
                onDeleted()
                modelContext.delete(recipient)
                try? modelContext.save()
            }
        } message: {
            Text("recipients.delete.message \(recipient.name)")
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        let records = sortedRecords
        for index in offsets {
            modelContext.delete(records[index])
        }
        try? modelContext.save()
    }
}
