import AtenaCore
import Contacts
import Observation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// CSV file picked by the user, read into memory.
struct CSVImportSource: Identifiable {
    let id = UUID()
    let data: Data
    let fileName: String
}

/// User-facing result message of an add/import action.
struct FlowMessage: Identifiable {
    let id = UUID()
    let title: LocalizedStringResource
    let body: String
    var offersPro = false
}

/// Shared presentation state for adding recipients (manual, contacts, CSV) and the paywall.
@Observable
final class RecipientAddFlow {
    enum Sheet: Identifiable {
        case newRecipient(group: RecipientGroup?)
        case editRecipient(Recipient)
        case csvImport(CSVImportSource)
        case paywall(PaywallReason)

        var id: String {
            switch self {
            case .newRecipient: "new"
            case .editRecipient(let recipient): "edit-\(recipient.persistentModelID.hashValue)"
            case .csvImport(let source): "csv-\(source.id)"
            case .paywall(let reason): "paywall-\(reason.rawValue)"
            }
        }
    }

    var sheet: Sheet?
    var isPickingContacts = false
    var isImportingFile = false
    var targetGroup: RecipientGroup?
    var message: FlowMessage?
}

extension View {
    func recipientAddFlow(_ flow: RecipientAddFlow) -> some View {
        modifier(RecipientAddFlowModifier(flow: flow))
    }
}

private struct RecipientAddFlowModifier: ViewModifier {
    @Bindable var flow: RecipientAddFlow
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var store

    func body(content: Content) -> some View {
        content
            .sheet(item: $flow.sheet) { sheet in
                switch sheet {
                case .newRecipient(let group):
                    RecipientEditorView(mode: .new(group: group))
                case .editRecipient(let recipient):
                    RecipientEditorView(mode: .edit(recipient))
                case .csvImport(let source):
                    CSVImportView(source: source, initialGroup: flow.targetGroup)
                case .paywall(let reason):
                    PaywallView(reason: reason)
                }
            }
            .background {
                ContactPickerPresenter(isPresented: $flow.isPickingContacts) { contacts in
                    importContacts(contacts)
                }
            }
            .fileImporter(isPresented: $flow.isImportingFile, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
                handlePickedFile(result)
            }
            .alert(
                flow.message.map { Text($0.title) } ?? Text(verbatim: ""),
                isPresented: Binding(get: { flow.message != nil }, set: { if !$0 { flow.message = nil } }),
                presenting: flow.message
            ) { message in
                if message.offersPro {
                    Button("store.learnMore") { flow.sheet = .paywall(.recipientLimit) }
                }
                Button("common.ok", role: .cancel) {}
            } message: { message in
                Text(verbatim: message.body)
            }
    }

    private func importContacts(_ contacts: [CNContact]) {
        let drafts = contacts.compactMap(ContactDraftMapper.draft(from:))
        guard !drafts.isEmpty else { return }
        let existing = (try? modelContext.fetch(FetchDescriptor<Recipient>())) ?? []
        var keys = Set(existing.map(\.duplicateKey))
        let remaining = FreeTier.remainingSlots(currentCount: existing.count, isPro: store.isPro)

        var imported = 0
        var duplicates = 0
        var overLimit = 0
        for draft in drafts {
            if keys.contains(draft.duplicateKey) {
                duplicates += 1
                continue
            }
            guard imported < remaining else {
                overLimit += 1
                continue
            }
            let recipient = Recipient(draft: draft)
            modelContext.insert(recipient)
            if let group = flow.targetGroup {
                recipient.groups.append(group)
            }
            keys.insert(draft.duplicateKey)
            imported += 1
        }
        try? modelContext.save()

        var lines = [String(localized: "contacts.result.imported \(imported)")]
        if duplicates > 0 { lines.append(String(localized: "contacts.result.duplicates \(duplicates)")) }
        if overLimit > 0 { lines.append(String(localized: "contacts.result.overLimit \(overLimit)")) }
        flow.message = FlowMessage(title: "contacts.result.title", body: lines.joined(separator: "\n"), offersPro: overLimit > 0)
    }

    private func handlePickedFile(_ result: Result<URL, any Error>) {
        guard case .success(let url) = result else { return }
        do {
            let data = try CSVFileReader.read(url: url, maxBytes: AppConstants.maxCSVImportBytes)
            flow.sheet = .csvImport(CSVImportSource(data: data, fileName: url.lastPathComponent))
        } catch CSVFileReader.ReadError.tooLarge {
            flow.message = FlowMessage(title: "csv.error.title", body: String(localized: "csv.error.tooLarge"))
        } catch {
            flow.message = FlowMessage(title: "csv.error.title", body: String(localized: "csv.error.unreadable"))
        }
    }
}

/// The "+" menu used in the sidebar and recipient list.
struct RecipientAddMenu: View {
    let targetGroup: RecipientGroup?
    @Environment(RecipientAddFlow.self) private var flow
    @Environment(StoreService.self) private var store
    @Query private var recipients: [Recipient]

    var body: some View {
        Menu {
            Button("add.manual", systemImage: "square.and.pencil") {
                flow.targetGroup = targetGroup
                flow.sheet = .newRecipient(group: targetGroup)
            }
            Button("add.contacts", systemImage: "person.crop.circle.badge.plus") {
                flow.targetGroup = targetGroup
                if FreeTier.remainingSlots(currentCount: recipients.count, isPro: store.isPro) == 0 {
                    flow.message = FlowMessage(title: "limit.title", body: String(localized: "limit.message \(AppConstants.freeRecipientLimit)"), offersPro: true)
                } else {
                    flow.isPickingContacts = true
                }
            }
            Button {
                flow.targetGroup = targetGroup
                if store.isPro {
                    flow.isImportingFile = true
                } else {
                    flow.sheet = .paywall(.csvImport)
                }
            } label: {
                Label(store.isPro ? LocalizedStringKey("add.csv") : LocalizedStringKey("add.csv.pro"), systemImage: "doc.text")
            }
        } label: {
            Label("add.menu", systemImage: "plus")
        }
    }
}

enum CSVFileReader {
    enum ReadError: Error {
        case tooLarge
    }

    /// Reads at most `maxBytes` without querying file metadata (no required-reason API use).
    static func read(url: URL, maxBytes: Int) throws -> Data {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maxBytes + 1) ?? Data()
        guard data.count <= maxBytes else { throw ReadError.tooLarge }
        return data
    }
}
