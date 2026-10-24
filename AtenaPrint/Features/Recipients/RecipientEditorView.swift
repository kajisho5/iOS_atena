import AtenaCore
import SwiftData
import SwiftUI

struct RecipientEditorView: View {
    enum Mode {
        case new(group: RecipientGroup?)
        case edit(Recipient)
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var store
    @Query(sort: \RecipientGroup.sortOrder) private var groups: [RecipientGroup]

    @State private var draft = RecipientDraft()
    @State private var usesCustomHonorific = false
    @State private var selectedGroupIDs = Set<PersistentIdentifier>()
    @State private var original: RecipientDraft?
    @State private var originalGroupIDs = Set<PersistentIdentifier>()
    @State private var isShowingPaywall = false
    @State private var isConfirmingDiscard = false
    @State private var didLoad = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case nameKana
        case honorific
        case jointName(Int)
        case postalCode
        case address1
        case address2
        case memo
    }

    /// Fields in the order Return / "次へ" moves through them.
    private var fieldOrder: [Field] {
        var order: [Field] = [.name, .nameKana]
        if usesCustomHonorific { order.append(.honorific) }
        order += draft.jointNames.indices.map { Field.jointName($0) }
        order += [.postalCode, .address1, .address2, .memo]
        return order
    }

    private func focusNextField() {
        guard let current = focusedField, let index = fieldOrder.firstIndex(of: current) else {
            focusedField = nil
            return
        }
        focusedField = fieldOrder.indices.contains(index + 1) ? fieldOrder[index + 1] : nil
    }

    private var isNew: Bool {
        if case .new = mode { true } else { false }
    }

    private var hasChanges: Bool {
        draft != (original ?? RecipientDraft()) || selectedGroupIDs != originalGroupIDs
    }

    private var canSave: Bool {
        !TextNormalization.trimmed(draft.name).isEmpty
    }

    private var postalCodeIsInvalid: Bool {
        !draft.postalCode.isEmpty && PostalCode.normalize(draft.postalCode) == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                jointNamesSection
                addressSection
                memoSection
                groupsSection
            }
            .onSubmit(focusNextField)
            .formKeyboardSupport(onNext: focusedField == .memo ? nil : focusNextField, onDone: { focusedField = nil })
            .navigationTitle(isNew ? Text("editor.title.new") : Text("editor.title.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(hasChanges)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        if hasChanges {
                            isConfirmingDiscard = true
                        } else {
                            dismiss()
                        }
                    }
                    .keyboardShortcut(.cancelAction)
                }
                // Kept in the top bar so the software keyboard never covers it.
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }
                        .disabled(!canSave)
                        .keyboardShortcut("s", modifiers: .command)
                }
            }
            .confirmationDialog("editor.discard.title", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                Button("editor.discard.confirm", role: .destructive) { dismiss() }
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView(reason: .recipientLimit)
            }
            .onAppear(perform: load)
        }
    }

    private var nameSection: some View {
        Section("editor.section.name") {
            TextField("editor.name", text: $draft.name, prompt: Text("editor.name.prompt"))
                .textContentType(.name)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
            TextField("editor.nameKana", text: $draft.nameKana, prompt: Text("editor.nameKana.prompt"))
                .focused($focusedField, equals: .nameKana)
                .submitLabel(.next)
            Picker("editor.honorific", selection: honorificChoice) {
                ForEach(Honorific.presets, id: \.self) { preset in
                    Text(verbatim: preset).tag(Optional(preset))
                }
                Text("editor.honorific.custom").tag(String?.none)
            }
            if usesCustomHonorific {
                TextField("editor.honorific.customField", text: $draft.honorific)
                    .focused($focusedField, equals: .honorific)
                    .submitLabel(.next)
            }
        }
    }

    private var jointNamesSection: some View {
        Section {
            ForEach(draft.jointNames.indices, id: \.self) { index in
                TextField("editor.jointName \(index + 1)", text: jointNameBinding(index))
                    .focused($focusedField, equals: .jointName(index))
                    .submitLabel(.next)
            }
            .onDelete { offsets in
                draft.jointNames.remove(atOffsets: offsets)
            }
            Button {
                draft.jointNames.append("")
                focusedField = .jointName(draft.jointNames.count - 1)
            } label: {
                Label("editor.jointNames.add", systemImage: "plus")
            }
        } header: {
            Text("editor.jointNames")
        } footer: {
            Text("editor.jointNames.footer")
        }
    }

    private var addressSection: some View {
        Section {
            TextField("editor.postalCode", text: $draft.postalCode, prompt: Text(verbatim: "1040061"))
                .keyboardType(.numberPad)
                .textContentType(.postalCode)
                .focused($focusedField, equals: .postalCode)
            TextField("editor.address1", text: $draft.address1, prompt: Text("editor.address1.prompt"))
                .textContentType(.fullStreetAddress)
                .focused($focusedField, equals: .address1)
                .submitLabel(.next)
            TextField("editor.address2", text: $draft.address2, prompt: Text("editor.address2.prompt"))
                .focused($focusedField, equals: .address2)
                .submitLabel(.next)
        } header: {
            Text("editor.section.address")
        } footer: {
            if postalCodeIsInvalid {
                Label("editor.postalCode.invalid", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.warningText)
            }
        }
    }

    private var memoSection: some View {
        Section("editor.memo") {
            TextField("editor.memo", text: $draft.memo, prompt: Text("editor.memo.prompt"), axis: .vertical)
                .focused($focusedField, equals: .memo)
        }
    }

    @ViewBuilder
    private var groupsSection: some View {
        if !groups.isEmpty {
            Section("editor.groups") {
                ForEach(groups) { group in
                    Button {
                        toggle(group)
                    } label: {
                        HStack {
                            Text(verbatim: group.name)
                                .foregroundStyle(Color.primary)
                            Spacer()
                            if selectedGroupIDs.contains(group.persistentModelID) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(selectedGroupIDs.contains(group.persistentModelID) ? .isSelected : [])
                }
            }
        }
    }

    private var honorificChoice: Binding<String?> {
        Binding {
            usesCustomHonorific ? nil : draft.honorific
        } set: { newValue in
            if let newValue {
                usesCustomHonorific = false
                draft.honorific = newValue
            } else {
                usesCustomHonorific = true
                if Honorific.presets.contains(draft.honorific) {
                    draft.honorific = ""
                }
            }
        }
    }

    private func jointNameBinding(_ index: Int) -> Binding<String> {
        Binding {
            draft.jointNames.indices.contains(index) ? draft.jointNames[index] : ""
        } set: { newValue in
            if draft.jointNames.indices.contains(index) {
                draft.jointNames[index] = newValue
            }
        }
    }

    private func toggle(_ group: RecipientGroup) {
        if selectedGroupIDs.contains(group.persistentModelID) {
            selectedGroupIDs.remove(group.persistentModelID)
        } else {
            selectedGroupIDs.insert(group.persistentModelID)
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        switch mode {
        case .new(let group):
            draft = RecipientDraft()
            if let group {
                selectedGroupIDs = [group.persistentModelID]
            }
            focusedField = .name
        case .edit(let recipient):
            draft = recipient.draft
            selectedGroupIDs = Set(recipient.groups.map(\.persistentModelID))
        }
        usesCustomHonorific = !Honorific.presets.contains(draft.honorific)
        original = draft
        originalGroupIDs = selectedGroupIDs
    }

    private func save() {
        guard canSave else { return }
        let recipient: Recipient
        switch mode {
        case .new:
            let count = (try? modelContext.fetchCount(FetchDescriptor<Recipient>())) ?? 0
            guard FreeTier.remainingSlots(currentCount: count, isPro: store.isPro) > 0 else {
                // Keep the input; the user can save again right after purchasing.
                isShowingPaywall = true
                return
            }
            recipient = Recipient(draft: draft)
            modelContext.insert(recipient)
        case .edit(let existing):
            recipient = existing
            recipient.apply(draft)
        }
        recipient.groups = groups.filter { selectedGroupIDs.contains($0.persistentModelID) }
        try? modelContext.save()
        dismiss()
    }
}
