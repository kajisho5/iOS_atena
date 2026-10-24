import SwiftData
import SwiftUI

struct GroupSidebarView: View {
    @Binding var selection: RecipientScope?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \RecipientGroup.sortOrder) private var groups: [RecipientGroup]
    @Query private var recipients: [Recipient]

    @State private var isAddingGroup = false
    @State private var groupName = ""
    @State private var renamingGroup: RecipientGroup?
    @State private var groupPendingDeletion: RecipientGroup?

    private var unprintedCount: Int {
        recipients.filter { !$0.isPrinted() }.count
    }

    var body: some View {
        List(selection: $selection) {
            Section {
                NavigationLink(value: RecipientScope.all) {
                    ScopeRow(title: Text("sidebar.all"), systemImage: "person.2", count: recipients.count)
                }
                NavigationLink(value: RecipientScope.unprinted) {
                    ScopeRow(title: Text("sidebar.unprinted"), systemImage: "tray", count: unprintedCount)
                }
            }
            Section {
                ForEach(groups) { group in
                    NavigationLink(value: RecipientScope.group(group)) {
                        ScopeRow(title: Text(verbatim: group.name), systemImage: "folder", count: group.recipients.count)
                    }
                    .contextMenu {
                        Button("groups.rename", systemImage: "pencil") { beginRename(group) }
                        Button("common.delete", systemImage: "trash", role: .destructive) { groupPendingDeletion = group }
                    }
                    .swipeActions {
                        Button("common.delete", systemImage: "trash", role: .destructive) { groupPendingDeletion = group }
                        Button("groups.rename", systemImage: "pencil") { beginRename(group) }
                    }
                }
                .onMove(perform: moveGroups)
                Button {
                    groupName = ""
                    isAddingGroup = true
                } label: {
                    Label("groups.add", systemImage: "plus")
                }
            } header: {
                Text("sidebar.groups")
            } footer: {
                Text("sidebar.groups.footer")
            }
        }
        .navigationTitle(Text("tab.recipients"))
        .safeAreaInset(edge: .bottom) {
            if horizontalSizeClass == .compact {
                BottomActionBar {
                    RecipientAddMenu(targetGroup: nil, style: .bar, barTitle: "add.menu")
                }
            }
        }
        .toolbar {
            if horizontalSizeClass != .compact {
                ToolbarItem(placement: .primaryAction) {
                    RecipientAddMenu(targetGroup: selection?.group)
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                EditButton()
            }
        }
        .alert("groups.add.title", isPresented: $isAddingGroup) {
            TextField("groups.name.placeholder", text: $groupName)
            Button("common.cancel", role: .cancel) {}
            Button("common.add") { addGroup() }
        }
        .alert("groups.rename.title", isPresented: Binding(get: { renamingGroup != nil }, set: { if !$0 { renamingGroup = nil } })) {
            TextField("groups.name.placeholder", text: $groupName)
            Button("common.cancel", role: .cancel) {}
            Button("common.save") { renameGroup() }
        }
        .confirmationDialog(
            "groups.delete.title",
            isPresented: Binding(get: { groupPendingDeletion != nil }, set: { if !$0 { groupPendingDeletion = nil } }),
            titleVisibility: .visible,
            presenting: groupPendingDeletion
        ) { group in
            Button("groups.delete.confirm", role: .destructive) { deleteGroup(group) }
        } message: { _ in
            Text("groups.delete.message")
        }
    }

    private func addGroup() {
        let name = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let group = RecipientGroup(name: name, sortOrder: (groups.map(\.sortOrder).max() ?? -1) + 1)
        modelContext.insert(group)
        try? modelContext.save()
    }

    private func beginRename(_ group: RecipientGroup) {
        groupName = group.name
        renamingGroup = group
    }

    private func renameGroup() {
        let name = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let renamingGroup, !name.isEmpty else { return }
        renamingGroup.name = name
        try? modelContext.save()
    }

    private func deleteGroup(_ group: RecipientGroup) {
        if selection == .group(group) {
            selection = .all
        }
        modelContext.delete(group)
        try? modelContext.save()
    }

    private func moveGroups(from source: IndexSet, to destination: Int) {
        var ordered = groups
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, group) in ordered.enumerated() {
            group.sortOrder = index
        }
        try? modelContext.save()
    }
}

private struct ScopeRow: View {
    let title: Text
    let systemImage: String
    let count: Int

    var body: some View {
        LabeledContent {
            Text(count, format: .number)
                .foregroundStyle(Color.secondaryText)
        } label: {
            Label {
                title
            } icon: {
                Image(systemName: systemImage)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
