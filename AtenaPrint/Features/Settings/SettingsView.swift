import AtenaCore
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var store
    @Query(sort: [SortDescriptor(\Recipient.sortKey)]) private var recipients: [Recipient]
    @Query private var senders: [SenderProfile]
    @Query private var printRecords: [PrintRecord]

    @State private var isShowingPaywall = false
    @State private var isConfirmingReset = false
    @State private var isRestoring = false
    @State private var message: LocalizedStringKey?

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("settings.section.print") {
                    NavigationLink {
                        SenderProfilesView()
                    } label: {
                        LabeledContent {
                            Text(senders.count, format: .number)
                        } label: {
                            Label("settings.senders", systemImage: "person.crop.circle")
                        }
                    }
                    NavigationLink {
                        PrintOffsetView()
                    } label: {
                        Label("settings.offset", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                    }
                }

                Section {
                    Button {
                        isShowingPaywall = true
                    } label: {
                        LabeledContent {
                            if store.isPro {
                                Label("settings.pro.owned", systemImage: "checkmark")
                                    .foregroundStyle(Color.successText)
                            }
                        } label: {
                            Label("settings.pro", systemImage: "tag")
                                .foregroundStyle(Color.primary)
                        }
                    }
                    Button {
                        restore()
                    } label: {
                        HStack {
                            Label("store.restore", systemImage: "arrow.clockwise")
                            if isRestoring {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRestoring)
                } header: {
                    Text("settings.section.pro")
                } footer: {
                    Text("settings.pro.footer")
                }

                Section {
                    ShareLink(item: CSVFile(data: CSVWriter.data(from: CSVTemplate.templateRows()), fileName: String(localized: "csv.template.fileName")),
                              preview: SharePreview("settings.csvTemplate")) {
                        Label("settings.csvTemplate", systemImage: "square.and.arrow.up")
                    }
                    ShareLink(item: CSVFile(data: CSVWriter.data(from: CSVTemplate.exportRows(recipients.map(\.draft))), fileName: String(localized: "csv.export.fileName")),
                              preview: SharePreview("settings.csvExport")) {
                        Label("settings.csvExport", systemImage: "tray.and.arrow.up")
                    }
                    .disabled(recipients.isEmpty)
                    Button("settings.resetRecords", role: .destructive) {
                        isConfirmingReset = true
                    }
                    .disabled(printRecords.isEmpty)
                } header: {
                    Text("settings.section.data")
                } footer: {
                    Text("settings.data.footer")
                }

                Section {
                    Link(destination: AppConstants.privacyPolicyURL) {
                        Label("settings.privacy", systemImage: "hand.raised")
                    }
                    Link(destination: AppConstants.termsOfUseURL) {
                        Label("settings.terms", systemImage: "doc.text")
                    }
                    LabeledContent("settings.version") {
                        Text(verbatim: appVersion)
                    }
                } header: {
                    Text("settings.section.about")
                } footer: {
                    Text("settings.about.footer")
                }
            }
            .navigationTitle(Text("tab.settings"))
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView(reason: .settings)
            }
            .confirmationDialog("settings.resetRecords.title", isPresented: $isConfirmingReset, titleVisibility: .visible) {
                Button("settings.resetRecords.confirm", role: .destructive) { resetRecords() }
            } message: {
                Text("settings.resetRecords.message")
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("common.ok", role: .cancel) {}
            }
        }
    }

    private func restore() {
        isRestoring = true
        Task {
            let restored = await store.restore()
            isRestoring = false
            message = restored ? "store.restore.success" : "store.restore.none"
        }
    }

    private func resetRecords() {
        for record in printRecords {
            modelContext.delete(record)
        }
        try? modelContext.save()
    }
}
