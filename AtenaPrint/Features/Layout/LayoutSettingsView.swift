import AtenaCore
import SwiftData
import SwiftUI

/// Layout tab (S09): live preview + layout options.
struct LayoutSettingsView: View {
    @Environment(LayoutStore.self) private var layoutStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: [SortDescriptor(\Recipient.sortKey)]) private var recipients: [Recipient]
    @Query(sort: \SenderProfile.sortOrder) private var senders: [SenderProfile]
    @State private var previewRecipientID: PersistentIdentifier?

    private var previewContent: AddressContent {
        if let recipient = recipients.first(where: { $0.persistentModelID == previewRecipientID }) ?? recipients.first {
            return AddressComposer.content(for: recipient)
        }
        return AddressComposer.sampleContent
    }

    var body: some View {
        NavigationStack {
            Group {
                if horizontalSizeClass == .regular {
                    HStack(spacing: 0) {
                        previewPanel
                            .padding(24)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.previewBackground)
                        form
                            .frame(maxWidth: 440)
                    }
                } else {
                    form
                }
            }
            .navigationTitle(Text("tab.layout"))
        }
    }

    private var previewPanel: some View {
        let settings = layoutStore.settings
        let sender = AddressComposer.sender(settings: settings, profiles: senders)
        let content = previewContent
        let layout = AddressComposer.layout(content, settings: settings, sender: sender)
        return VStack(spacing: 12) {
            AddressSheetView(layout: layout, font: settings.font,
                             accessibilitySummary: AddressComposer.accessibilitySummary(content, settings: settings, layout: layout))
            if layout.hasOverflow {
                OverflowWarning()
            }
        }
    }

    private var form: some View {
        @Bindable var store = layoutStore
        return Form {
            if horizontalSizeClass != .regular {
                Section {
                    previewPanel
                        .frame(height: 280)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .listRowBackground(Color.previewBackground)
                }
            }
            if !recipients.isEmpty {
                Section {
                    Picker("layout.previewRecipient", selection: $previewRecipientID) {
                        Text("layout.previewRecipient.first").tag(PersistentIdentifier?.none)
                        ForEach(recipients) { recipient in
                            Text(verbatim: recipient.name).tag(Optional(recipient.persistentModelID))
                        }
                    }
                }
            }
            Section {
                Picker("layout.paper", selection: $store.settings.paper) {
                    ForEach(PaperKind.allCases) { paper in
                        Text(verbatim: paper.localizedName + "（" + paper.dimensionText + "）").tag(paper)
                    }
                }
                Picker("layout.writingMode", selection: $store.settings.writingMode) {
                    ForEach(WritingMode.allCases) { mode in
                        Text(verbatim: mode.localizedName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Picker("layout.font", selection: $store.settings.font) {
                    ForEach(AddressFont.allCases) { font in
                        Text(verbatim: font.localizedName).tag(font)
                    }
                }
                Toggle("layout.kanjiDigits", isOn: $store.settings.convertDigitsToKanji)
                    .disabled(store.settings.writingMode == .horizontal)
            } footer: {
                if store.settings.paper.exceedsA4Width {
                    Label("layout.paper.kakugata2Note", systemImage: "info.circle")
                } else if store.settings.writingMode == .horizontal {
                    Text("layout.kanjiDigits.verticalOnly")
                } else {
                    Text("layout.autoShrink")
                }
            }
            Section {
                Toggle("layout.printsSender", isOn: $store.settings.printsSender)
                if store.settings.printsSender {
                    if senders.isEmpty {
                        NavigationLink {
                            SenderProfilesView()
                        } label: {
                            Label("layout.sender.register", systemImage: "person.crop.circle.badge.plus")
                        }
                    } else {
                        Picker("layout.sender", selection: senderSelection) {
                            ForEach(senders) { sender in
                                Text(verbatim: sender.label.isEmpty ? sender.name : sender.label).tag(Optional(sender.uuid))
                            }
                        }
                    }
                }
            }
            Section {
                NavigationLink {
                    PrintOffsetView()
                } label: {
                    Label("settings.offset", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                }
            }
        }
    }

    private var senderSelection: Binding<UUID?> {
        Binding {
            AddressComposer.sender(settings: layoutStore.settings, profiles: senders)?.uuid
        } set: { newValue in
            layoutStore.settings.senderID = newValue
        }
    }
}
