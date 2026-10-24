import AtenaCore
import SwiftData
import SwiftUI

enum PrintFilter: String, CaseIterable, Identifiable {
    case all
    case unprinted
    case printed

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .all: "filter.all"
        case .unprinted: "filter.unprinted"
        case .printed: "filter.printed"
        }
    }
}

enum RecipientSortOrder: String, CaseIterable, Identifiable {
    case reading
    case created
    case postalCode

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .reading: "sort.reading"
        case .created: "sort.created"
        case .postalCode: "sort.postalCode"
        }
    }
}

struct RecipientListView: View {
    let scope: RecipientScope
    @Binding var selection: Recipient?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.printRequestHandler) private var requestPrint
    @Environment(RecipientAddFlow.self) private var addFlow
    @Query(sort: [SortDescriptor(\Recipient.sortKey), SortDescriptor(\Recipient.createdAt)]) private var allRecipients: [Recipient]

    @State private var searchText = ""
    @State private var filter: PrintFilter = .all
    @State private var pendingDeletion: Recipient?
    @State private var isChoosingBatchScope = false
    @State private var isSelectingForPrint = false
    @AppStorage("pref.recipientSortOrder") private var sortOrder: RecipientSortOrder = .reading

    private var group: RecipientGroup? { scope.group }

    private var scopedRecipients: [Recipient] {
        switch scope {
        case .all:
            return allRecipients
        case .unprinted:
            return allRecipients.filter { !$0.isPrinted() }
        case .group(let group):
            return allRecipients.filter { recipient in
                recipient.groups.contains { $0.persistentModelID == group.persistentModelID }
            }
        }
    }

    private var visibleRecipients: [Recipient] {
        var result = scopedRecipients
        switch filter {
        case .all: break
        case .unprinted: result = result.filter { !$0.isPrinted(in: group) }
        case .printed: result = result.filter { $0.isPrinted(in: group) }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            let digits = PostalCode.digitsOnly(query)
            result = result.filter { recipient in
                recipient.name.localizedStandardContains(query)
                    || recipient.nameKana.localizedStandardContains(query)
                    || recipient.address1.localizedStandardContains(query)
                    || recipient.address2.localizedStandardContains(query)
                    || recipient.jointNames.contains { $0.localizedStandardContains(query) }
                    || (!digits.isEmpty && recipient.postalCode.contains(digits))
            }
        }
        switch sortOrder {
        case .reading: break
        case .created: result.sort { $0.createdAt < $1.createdAt }
        case .postalCode: result.sort { $0.postalCode < $1.postalCode }
        }
        return result
    }

    private var unprintedInScope: [Recipient] {
        scopedRecipients.filter { !$0.isPrinted(in: group) }
    }

    private var title: Text {
        switch scope {
        case .all: Text("sidebar.all")
        case .unprinted: Text("sidebar.unprinted")
        case .group(let group): Text(verbatim: group.name)
        }
    }

    var body: some View {
        List(selection: $selection) {
            if !scopedRecipients.isEmpty {
                Section {
                    ForEach(visibleRecipients) { recipient in
                        NavigationLink(value: recipient) {
                            RecipientRowView(recipient: recipient, group: group)
                        }
                        .swipeActions {
                            Button("common.delete", systemImage: "trash", role: .destructive) {
                                pendingDeletion = recipient
                            }
                            Button("common.edit", systemImage: "pencil") {
                                addFlow.sheet = .editRecipient(recipient)
                            }
                        }
                        .contextMenu {
                            Button("common.edit", systemImage: "pencil") { addFlow.sheet = .editRecipient(recipient) }
                            Button("recipients.printThis", systemImage: "printer") {
                                requestPrint(PrintRequest(recipients: [recipient], group: group))
                            }
                            Button("common.delete", systemImage: "trash", role: .destructive) { pendingDeletion = recipient }
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("recipients.summary \(scopedRecipients.count) \(unprintedInScope.count)")
                            .foregroundStyle(Color.secondaryText)
                        if scope != .unprinted {
                            Picker("filter.title", selection: $filter) {
                                ForEach(PrintFilter.allCases) { filter in
                                    Text(filter.title).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .textCase(nil)
                    .padding(.bottom, 4)
                }
            }
        }
        .overlay { emptyState }
        .searchable(text: $searchText, prompt: Text("recipients.search.prompt"))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            // iPhone: primary actions sit at the bottom, within thumb reach.
            if horizontalSizeClass == .compact, !scopedRecipients.isEmpty {
                BottomActionBar {
                    HStack(spacing: 12) {
                        RecipientAddMenu(targetGroup: group, style: .bar, providesShortcuts: true)
                            .frame(maxWidth: 140)
                        batchPrintButton(inBar: true)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if horizontalSizeClass != .compact {
                    batchPrintButton(inBar: false)
                    RecipientAddMenu(targetGroup: group, providesShortcuts: true)
                }
                Menu {
                    Button("print.select", systemImage: "checklist") { isSelectingForPrint = true }
                        .disabled(scopedRecipients.isEmpty)
                    Picker(selection: $sortOrder) {
                        ForEach(RecipientSortOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    } label: {
                        Label("sort.title", systemImage: "arrow.up.arrow.down")
                    }
                    .pickerStyle(.menu)
                } label: {
                    Label("common.more", systemImage: "ellipsis")
                }
            }
        }
        .confirmationDialog("print.batch.title", isPresented: $isChoosingBatchScope, titleVisibility: .visible) {
            Button("print.batch.unprinted \(unprintedInScope.count)") {
                requestPrint(PrintRequest(recipients: unprintedInScope, group: group))
            }
            .disabled(unprintedInScope.isEmpty)
            Button("print.batch.all \(scopedRecipients.count)") {
                requestPrint(PrintRequest(recipients: scopedRecipients, group: group))
            }
        }
        .confirmationDialog(
            "recipients.delete.title",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { recipient in
            Button("recipients.delete.confirm", role: .destructive) { delete(recipient) }
        } message: { recipient in
            Text("recipients.delete.message \(recipient.name)")
        }
        .sheet(isPresented: $isSelectingForPrint) {
            RecipientPrintSelectionView(recipients: visibleRecipients, group: group) { chosen in
                requestPrint(PrintRequest(recipients: chosen, group: group))
            }
        }
    }

    private func batchPrintButton(inBar: Bool) -> some View {
        Button {
            isChoosingBatchScope = true
        } label: {
            if inBar {
                Label("print.batch", systemImage: "printer")
                    .primaryActionLabel()
            } else {
                Label("print.batch", systemImage: "printer")
            }
        }
        .disabled(scopedRecipients.isEmpty)
        .keyboardShortcut("p", modifiers: [.command, .shift])
        .hoverEffect()
    }

    @ViewBuilder
    private var emptyState: some View {
        if scopedRecipients.isEmpty {
            switch scope {
            case .all:
                ContentUnavailableView {
                    Label("empty.recipients.title", systemImage: "person.2")
                } description: {
                    Text("empty.recipients.message")
                } actions: {
                    EmptyAddActions(group: nil)
                }
            case .unprinted:
                ContentUnavailableView("empty.unprinted.title", systemImage: "checkmark.circle", description: Text("empty.unprinted.message"))
            case .group(let group):
                ContentUnavailableView {
                    Label("empty.group.title", systemImage: "folder")
                } description: {
                    Text("empty.group.message")
                } actions: {
                    EmptyAddActions(group: group)
                }
            }
        } else if visibleRecipients.isEmpty {
            if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ContentUnavailableView("empty.filter.title", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
    }

    private func delete(_ recipient: Recipient) {
        if selection == recipient {
            selection = nil
        }
        modelContext.delete(recipient)
        try? modelContext.save()
    }
}

/// Buttons shown in the empty state; same actions as the "+" menu.
private struct EmptyAddActions: View {
    let group: RecipientGroup?
    @Environment(RecipientAddFlow.self) private var flow

    var body: some View {
        VStack(spacing: 12) {
            Button("add.manual") {
                flow.targetGroup = group
                flow.sheet = .newRecipient(group: group)
            }
            .buttonStyle(.borderedProminent)
            Button("add.contacts") {
                flow.targetGroup = group
                flow.isPickingContacts = true
            }
            .buttonStyle(.bordered)
            Button("add.csv") {
                flow.targetGroup = group
                flow.isImportingFile = true
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
    }
}
