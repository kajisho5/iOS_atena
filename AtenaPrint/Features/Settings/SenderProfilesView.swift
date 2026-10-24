import AtenaCore
import SwiftData
import SwiftUI

/// Sender profiles (S11), e.g. home and work.
struct SenderProfilesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SenderProfile.sortOrder) private var senders: [SenderProfile]
    @State private var editing: SenderProfile?
    @State private var isAdding = false

    var body: some View {
        List {
            ForEach(senders) { sender in
                Button {
                    editing = sender
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: sender.label.isEmpty ? sender.name : sender.label)
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                        Text(verbatim: sender.name + "  〒" + PostalCode.formatted(sender.postalCode) + " " + sender.address1)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryText)
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    modelContext.delete(senders[index])
                }
                try? modelContext.save()
            }
            .onMove { source, destination in
                var ordered = senders
                ordered.move(fromOffsets: source, toOffset: destination)
                for (index, sender) in ordered.enumerated() {
                    sender.sortOrder = index
                }
                try? modelContext.save()
            }
        }
        .overlay {
            if senders.isEmpty {
                ContentUnavailableView {
                    Label("senders.empty.title", systemImage: "person.crop.circle")
                } description: {
                    Text("senders.empty.message")
                } actions: {
                    Button("senders.add") { isAdding = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle(Text("settings.senders"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAdding = true
                } label: {
                    Label("senders.add", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                EditButton()
            }
        }
        .sheet(item: $editing) { sender in
            SenderEditorView(sender: sender)
        }
        .sheet(isPresented: $isAdding) {
            SenderEditorView(sender: nil)
        }
    }
}

struct SenderEditorView: View {
    let sender: SenderProfile?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var senders: [SenderProfile]

    @State private var label = ""
    @State private var name = ""
    @State private var jointNames: [String] = []
    @State private var postalCode = ""
    @State private var address1 = ""
    @State private var address2 = ""
    @State private var didLoad = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case label
        case name
        case jointName(Int)
        case postalCode
        case address1
        case address2
    }

    private var fieldOrder: [Field] {
        [.label, .name] + jointNames.indices.map { Field.jointName($0) } + [.postalCode, .address1, .address2]
    }

    private func focusNextField() {
        guard let current = focusedField, let index = fieldOrder.firstIndex(of: current) else {
            focusedField = nil
            return
        }
        focusedField = fieldOrder.indices.contains(index + 1) ? fieldOrder[index + 1] : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("senders.label", text: $label, prompt: Text("senders.label.prompt"))
                        .focused($focusedField, equals: .label)
                        .submitLabel(.next)
                } footer: {
                    Text("senders.label.footer")
                }
                Section("editor.section.name") {
                    TextField("editor.name", text: $name, prompt: Text("editor.name.prompt"))
                        .textContentType(.name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                    ForEach(jointNames.indices, id: \.self) { index in
                        TextField("editor.jointName \(index + 1)", text: Binding(
                            get: { jointNames.indices.contains(index) ? jointNames[index] : "" },
                            set: { if jointNames.indices.contains(index) { jointNames[index] = $0 } }
                        ))
                        .focused($focusedField, equals: .jointName(index))
                        .submitLabel(.next)
                    }
                    .onDelete { jointNames.remove(atOffsets: $0) }
                    Button {
                        jointNames.append("")
                        focusedField = .jointName(jointNames.count - 1)
                    } label: {
                        Label("editor.jointNames.add", systemImage: "plus")
                    }
                }
                Section("editor.section.address") {
                    TextField("editor.postalCode", text: $postalCode, prompt: Text(verbatim: "1230045"))
                        .keyboardType(.numberPad)
                        .textContentType(.postalCode)
                        .focused($focusedField, equals: .postalCode)
                    TextField("editor.address1", text: $address1, prompt: Text("editor.address1.prompt"))
                        .textContentType(.fullStreetAddress)
                        .focused($focusedField, equals: .address1)
                        .submitLabel(.next)
                    TextField("editor.address2", text: $address2, prompt: Text("editor.address2.prompt"))
                        .focused($focusedField, equals: .address2)
                        .submitLabel(.done)
                }
            }
            .onSubmit { focusNextField() }
            .formKeyboardSupport(showsNext: focusedField != .address2, onNext: { focusNextField() }, onDone: { focusedField = nil })
            .navigationTitle(sender == nil ? Text("senders.title.new") : Text("senders.title.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut("s", modifiers: .command)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let sender else { return }
        label = sender.label
        name = sender.name
        jointNames = sender.jointNames
        postalCode = sender.postalCode
        address1 = sender.address1
        address2 = sender.address2
    }

    private func save() {
        let target: SenderProfile
        if let sender {
            target = sender
        } else {
            target = SenderProfile(label: "", sortOrder: (senders.map(\.sortOrder).max() ?? -1) + 1)
            modelContext.insert(target)
        }
        target.label = TextNormalization.trimmed(label)
        target.name = TextNormalization.trimmed(name)
        target.jointNames = jointNames.map(TextNormalization.trimmed).filter { !$0.isEmpty }
        target.postalCode = PostalCode.digitsOnly(postalCode)
        target.address1 = TextNormalization.trimmed(address1)
        target.address2 = TextNormalization.trimmed(address2)
        try? modelContext.save()
        dismiss()
    }
}
