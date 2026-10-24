import AtenaCore
import SwiftData
import SwiftUI

/// CSV import: column mapping review → import → result.
/// Available in the free version as well, limited by the free recipient count, so people can
/// check how their file is read before deciding to buy Pro.
struct CSVImportView: View {
    let source: CSVImportSource
    let initialGroup: RecipientGroup?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var store
    @Query(sort: \RecipientGroup.sortOrder) private var groups: [RecipientGroup]
    @Query private var existingRecipients: [Recipient]

    @State private var encoding: CSVEncoding = .utf8
    @State private var rows: [[String]] = []
    @State private var lineNumbers: [Int] = []
    @State private var decodeFailed = false
    @State private var hasHeader = true
    @State private var mapping = ColumnMapping()
    @State private var candidates: [ImportCandidate] = []
    @State private var targetGroupID: PersistentIdentifier?
    @State private var result: ImportResult?
    @State private var didLoad = false
    @State private var isShowingPaywall = false

    struct ImportResult {
        let imported: Int
        let skipped: [ImportCandidate]
        /// Rows not imported because the free recipient limit was reached.
        let overLimit: [ImportCandidate]
        let warnings: Int
    }

    private var columnCount: Int {
        rows.map(\.count).max() ?? 0
    }

    private var headerRow: [String] {
        hasHeader ? (rows.first ?? []) : []
    }

    private var importable: [ImportCandidate] {
        candidates.filter { $0.isIncluded && $0.status != .missingName }
    }

    private var includedCount: Int {
        importable.count
    }

    /// Rows that will actually be imported now (the free version stops at the recipient limit).
    private var importCount: Int {
        min(includedCount, FreeTier.remainingSlots(currentCount: existingRecipients.count, isPro: store.isPro))
    }

    private var isLimitedByFreeTier: Bool {
        importCount < includedCount
    }

    var body: some View {
        NavigationStack {
            Group {
                if let result {
                    resultView(result)
                } else {
                    mappingForm
                }
            }
            .navigationTitle(result == nil ? Text("csv.mapping.title") : Text("csv.result.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Every sheet is dismissed from the top-leading corner.
                ToolbarItem(placement: .cancellationAction) {
                    Button(result == nil ? LocalizedStringKey("common.cancel") : LocalizedStringKey("common.close")) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .safeAreaInset(edge: .bottom) {
                // No text input on this screen, so the primary action sits at the bottom.
                BottomActionBar {
                    if result == nil {
                        Button {
                            performImport()
                        } label: {
                            Text("csv.import \(importCount)")
                                .primaryActionLabel()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(importCount == 0 || mapping[.name] == nil)
                        .keyboardShortcut(.defaultAction)
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Text("common.done")
                                .primaryActionLabel()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
            .interactiveDismissDisabled(result == nil && includedCount > 0)
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView(reason: .csvImport)
            }
            .onAppear(perform: load)
        }
    }

    // MARK: - Mapping

    private var mappingForm: some View {
        Form {
            Section {
                LabeledContent("csv.file") { Text(verbatim: source.fileName) }
                Picker("csv.encoding", selection: $encoding) {
                    Text("csv.encoding.utf8").tag(CSVEncoding.utf8)
                    Text("csv.encoding.shiftJIS").tag(CSVEncoding.shiftJIS)
                }
                Toggle("csv.hasHeader", isOn: $hasHeader)
            } footer: {
                if decodeFailed {
                    Label("csv.error.encoding", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.warningText)
                }
            }

            if columnCount > 0 {
                Section {
                    ForEach(RecipientField.allCases) { field in
                        Picker(selection: mappingBinding(field)) {
                            Text("csv.column.unused").tag(Int?.none)
                            ForEach(0..<columnCount, id: \.self) { index in
                                Text(columnLabel(index)).tag(Optional(index))
                            }
                        } label: {
                            Text(field.localizedName)
                        }
                    }
                } header: {
                    Text("csv.mapping.header")
                } footer: {
                    if mapping[.name] == nil {
                        Label("csv.mapping.nameRequired", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.warningText)
                    }
                }

                Section("csv.preview.header") {
                    ForEach(candidates.prefix(5)) { candidate in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: candidate.draft.name.isEmpty ? "—" : candidate.draft.name + " " + candidate.draft.honorific)
                                .font(.headline)
                            Text(verbatim: "〒" + PostalCode.formatted(candidate.draft.postalCode) + " " + candidate.draft.address1 + " " + candidate.draft.address2)
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                let duplicates = candidates.filter { $0.status == .possibleDuplicate }
                if !duplicates.isEmpty {
                    Section {
                        ForEach(duplicates) { candidate in
                            Toggle(isOn: includeBinding(candidate.id)) {
                                VStack(alignment: .leading) {
                                    Text(verbatim: candidate.draft.name)
                                    Text("csv.line \(candidate.id)")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondaryText)
                                }
                            }
                        }
                    } header: {
                        Text("csv.duplicates.header")
                    } footer: {
                        Text("csv.duplicates.footer")
                    }
                }

                Section("csv.target.header") {
                    Picker("csv.target", selection: $targetGroupID) {
                        Text("csv.target.none").tag(PersistentIdentifier?.none)
                        ForEach(groups) { group in
                            Text(verbatim: group.name).tag(Optional(group.persistentModelID))
                        }
                    }
                }

                Section {
                    Label {
                        Text("csv.summary \(candidates.count) \(importCount)")
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    if isLimitedByFreeTier {
                        Label {
                            Text("csv.limit.notice \(AppConstants.freeRecipientLimit) \(importCount) \(includedCount - importCount)")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .foregroundStyle(Color.warningText)
                        Button("store.learnMore") { isShowingPaywall = true }
                    }
                } footer: {
                    if !store.isPro {
                        Text("csv.limit.footer \(AppConstants.freeRecipientLimit)")
                    }
                }
            } else if !decodeFailed {
                ContentUnavailableView("csv.empty.title", systemImage: "doc.text", description: Text("csv.empty.message"))
            }
        }
        .onChange(of: encoding) { decode() }
        .onChange(of: hasHeader) {
            mapping = hasHeader ? ColumnMapping.automatic(headers: headerRow) : ColumnMapping.templateOrder(columnCount: columnCount)
            replan()
        }
        .onChange(of: mapping) { replan() }
    }

    private func columnLabel(_ index: Int) -> String {
        let header = headerRow.indices.contains(index) ? headerRow[index] : ""
        let sample = rows.dropFirst(hasHeader ? 1 : 0).first.flatMap { $0.indices.contains(index) ? $0[index] : nil } ?? ""
        let title = header.isEmpty ? String(localized: "csv.column \(index + 1)") : header
        return sample.isEmpty ? title : "\(title)（\(sample.prefix(12))）"
    }

    private func mappingBinding(_ field: RecipientField) -> Binding<Int?> {
        Binding {
            mapping[field]
        } set: { newValue in
            // A column feeds one field only.
            if let newValue {
                for other in RecipientField.allCases where mapping[other] == newValue {
                    mapping[other] = nil
                }
            }
            mapping[field] = newValue
        }
    }

    private func includeBinding(_ id: Int) -> Binding<Bool> {
        Binding {
            candidates.first { $0.id == id }?.isIncluded ?? false
        } set: { newValue in
            if let index = candidates.firstIndex(where: { $0.id == id }) {
                candidates[index].isIncluded = newValue
            }
        }
    }

    // MARK: - Loading

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        targetGroupID = initialGroup?.persistentModelID
        encoding = CSVTextDecoder.detectEncoding(of: source.data) ?? .utf8
        decode()
    }

    private func decode() {
        do {
            let text = try CSVTextDecoder.decode(source.data, as: encoding)
            let parsed = CSVParser.parseRows(text)
            rows = parsed.map(\.fields)
            lineNumbers = parsed.map(\.line)
            decodeFailed = false
        } catch {
            rows = []
            decodeFailed = true
        }
        mapping = hasHeader ? ColumnMapping.automatic(headers: headerRow) : ColumnMapping.templateOrder(columnCount: columnCount)
        replan()
    }

    private func replan() {
        let existing = (try? modelContext.fetch(FetchDescriptor<Recipient>())) ?? []
        candidates = ImportPlanner.plan(rows: rows, hasHeader: hasHeader, mapping: mapping, existingKeys: Set(existing.map(\.duplicateKey)),
                                         lineNumbers: lineNumbers)
    }

    // MARK: - Import

    private func performImport() {
        let group = groups.first { $0.persistentModelID == targetGroupID }
        let limit = importCount
        let rows = importable
        var imported = 0
        var warnings = 0
        for candidate in rows.prefix(limit) {
            let recipient = Recipient(draft: candidate.draft)
            modelContext.insert(recipient)
            if let group {
                recipient.groups.append(group)
            }
            imported += 1
            if !candidate.warnings.isEmpty { warnings += 1 }
        }
        try? modelContext.save()
        result = ImportResult(imported: imported, skipped: candidates.filter { !$0.isIncluded || $0.status == .missingName },
                              overLimit: Array(rows.dropFirst(limit)), warnings: warnings)
    }

    private func resultView(_ result: ImportResult) -> some View {
        List {
            Section {
                Label("csv.result.imported \(result.imported)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.successText)
                if result.warnings > 0 {
                    Label("csv.result.warnings \(result.warnings)", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.warningText)
                }
            }
            if !result.overLimit.isEmpty {
                Section {
                    Label("csv.result.overLimit \(result.overLimit.count)", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.warningText)
                    Button("store.learnMore") { isShowingPaywall = true }
                } footer: {
                    Text("csv.result.overLimit.footer")
                }
            }
            if !result.skipped.isEmpty {
                Section("csv.result.skipped \(result.skipped.count)") {
                    ForEach(result.skipped) { candidate in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("csv.line \(candidate.id)")
                                .font(.headline)
                            Text(candidate.status == .missingName ? LocalizedStringKey("csv.skip.missingName") : LocalizedStringKey("csv.skip.duplicate"))
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}

extension RecipientField {
    var localizedName: LocalizedStringKey {
        switch self {
        case .name: "editor.name"
        case .nameKana: "editor.nameKana"
        case .jointNames: "editor.jointNames"
        case .honorific: "editor.honorific"
        case .postalCode: "editor.postalCode"
        case .address1: "editor.address1"
        case .address2: "editor.address2"
        case .memo: "editor.memo"
        }
    }
}
