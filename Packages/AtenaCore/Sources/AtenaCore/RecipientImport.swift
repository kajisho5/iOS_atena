import Foundation

/// Fields of a recipient that can be filled from CSV columns.
public enum RecipientField: String, CaseIterable, Sendable, Identifiable {
    case name
    case nameKana
    case jointNames
    case honorific
    case postalCode
    case address1
    case address2
    case memo

    public var id: String { rawValue }

    /// Fields defined by the product specification (always shown in the template).
    public static let templateFields: [RecipientField] = [.name, .jointNames, .postalCode, .address1, .memo]

    /// Header synonyms used for automatic column mapping (compared after normalization).
    static let synonyms: [RecipientField: [String]] = [
        .name: ["氏名", "名前", "お名前", "宛名", "name", "fullname", "姓名", "会社名"],
        .nameKana: ["ふりがな", "フリガナ", "よみ", "ヨミ", "読み", "かな", "カナ", "kana", "furigana"],
        .jointNames: ["連名", "連名1", "家族", "jointnames", "joint"],
        .honorific: ["敬称", "honorific", "title"],
        .postalCode: ["郵便番号", "〒", "郵便", "zip", "zipcode", "postalcode", "postcode"],
        .address1: ["住所", "住所1", "住所１", "address", "address1"],
        .address2: ["住所2", "住所２", "建物名", "建物", "マンション名", "address2", "building"],
        .memo: ["メモ", "備考", "memo", "note", "notes", "comment"],
    ]

    /// Template header label written to the exported template CSV.
    public var templateHeader: String {
        switch self {
        case .name: "氏名"
        case .nameKana: "ふりがな"
        case .jointNames: "連名"
        case .honorific: "敬称"
        case .postalCode: "郵便番号"
        case .address1: "住所"
        case .address2: "住所2"
        case .memo: "メモ"
        }
    }
}

/// Maps recipient fields to CSV column indexes.
public struct ColumnMapping: Equatable, Sendable {
    public var columns: [RecipientField: Int]

    public init(columns: [RecipientField: Int] = [:]) {
        self.columns = columns
    }

    public subscript(field: RecipientField) -> Int? {
        get { columns[field] }
        set { columns[field] = newValue }
    }

    /// Guesses the mapping from a header row. Each column is used for at most one field.
    public static func automatic(headers: [String]) -> ColumnMapping {
        var mapping = ColumnMapping()
        var used = Set<Int>()
        let normalizedHeaders = headers.map(normalizeHeader)
        for field in RecipientField.allCases {
            let candidates = (RecipientField.synonyms[field] ?? []).map(normalizeHeader)
            if let index = normalizedHeaders.indices.first(where: { !used.contains($0) && candidates.contains(normalizedHeaders[$0]) }) {
                mapping[field] = index
                used.insert(index)
            }
        }
        return mapping
    }

    /// Mapping for a file without a header row: assumes the template column order.
    public static func templateOrder(columnCount: Int) -> ColumnMapping {
        var mapping = ColumnMapping()
        for (index, field) in RecipientField.templateFields.enumerated() where index < columnCount {
            mapping[field] = index
        }
        return mapping
    }

    static func normalizeHeader(_ header: String) -> String {
        TextNormalization.removingSpaces(TextNormalization.halfWidthDigits(header))
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
    }
}

/// A recipient parsed from an external source, before it is persisted.
public struct RecipientDraft: Equatable, Sendable {
    public var name: String
    public var nameKana: String
    public var jointNames: [String]
    public var honorific: String
    public var postalCode: String
    public var address1: String
    public var address2: String
    public var memo: String

    public init(name: String = "", nameKana: String = "", jointNames: [String] = [], honorific: String = Honorific.defaultValue,
                postalCode: String = "", address1: String = "", address2: String = "", memo: String = "") {
        self.name = name
        self.nameKana = nameKana
        self.jointNames = jointNames
        self.honorific = honorific
        self.postalCode = postalCode
        self.address1 = address1
        self.address2 = address2
        self.memo = memo
    }

    /// Key used to detect likely duplicates: name without spaces + postal code digits.
    public var duplicateKey: String {
        DuplicateKey.make(name: name, postalCode: postalCode)
    }

    /// Splits a joint-name cell ("花子・一郎", "花子、一郎", "花子/一郎") into names.
    public static func splitJointNames(_ text: String) -> [String] {
        let separators: Set<Character> = ["・", "、", ",", "，", "/", "／", ";", "；", "\n"]
        return text.split(whereSeparator: { separators.contains($0) })
            .map { TextNormalization.trimmed(String($0)) }
            .filter { !$0.isEmpty }
    }
}

public enum DuplicateKey {
    public static func make(name: String, postalCode: String) -> String {
        TextNormalization.removingSpaces(name) + "|" + PostalCode.digitsOnly(postalCode)
    }
}

public enum Honorific {
    public static let defaultValue = "様"
    /// Presets offered in the editor. Free text is also allowed.
    public static let presets = ["様", "殿", "先生", "御中", "行"]
}

/// Outcome of planning the import of one CSV row.
public struct ImportCandidate: Identifiable, Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        /// Will be imported.
        case ready
        /// Name is empty; cannot be imported.
        case missingName
        /// Same name and postal code already exist (in the app or earlier in the file).
        case possibleDuplicate
    }

    public enum Warning: Equatable, Sendable {
        case invalidPostalCode
        case missingAddress
    }

    /// 1-based line number in the source file (header counted).
    public let id: Int
    public var draft: RecipientDraft
    public var status: Status
    public var warnings: [Warning]
    /// Whether the row will be imported. Duplicates default to `false` and can be toggled.
    public var isIncluded: Bool
}

public enum ImportPlanner {
    /// Builds import candidates from parsed CSV rows.
    /// - Parameters:
    ///   - rows: All rows of the file.
    ///   - hasHeader: Whether the first row is a header (skipped).
    ///   - mapping: Field to column mapping.
    ///   - existingKeys: Duplicate keys of recipients that already exist.
    public static func plan(rows: [[String]], hasHeader: Bool, mapping: ColumnMapping, existingKeys: Set<String>) -> [ImportCandidate] {
        var seen = existingKeys
        var candidates: [ImportCandidate] = []
        let dataRows = hasHeader ? Array(rows.dropFirst()) : rows
        for (offset, row) in dataRows.enumerated() {
            let lineNumber = offset + (hasHeader ? 2 : 1)
            func value(_ field: RecipientField) -> String {
                guard let index = mapping[field], row.indices.contains(index) else { return "" }
                return TextNormalization.trimmed(CSVWriter.unescapeFormulaGuard(row[index]))
            }
            if row.allSatisfy({ TextNormalization.trimmed($0).isEmpty }) { continue }

            let rawPostal = value(.postalCode)
            let normalizedPostal = PostalCode.normalize(rawPostal)
            let honorific = value(.honorific)
            let draft = RecipientDraft(
                name: value(.name),
                nameKana: value(.nameKana),
                jointNames: RecipientDraft.splitJointNames(value(.jointNames)),
                honorific: honorific.isEmpty ? Honorific.defaultValue : honorific,
                postalCode: normalizedPostal ?? PostalCode.digitsOnly(rawPostal),
                address1: value(.address1),
                address2: value(.address2),
                memo: value(.memo)
            )
            var warnings: [ImportCandidate.Warning] = []
            if normalizedPostal == nil { warnings.append(.invalidPostalCode) }
            if draft.address1.isEmpty { warnings.append(.missingAddress) }

            let status: ImportCandidate.Status
            if draft.name.isEmpty {
                status = .missingName
            } else if seen.contains(draft.duplicateKey) {
                status = .possibleDuplicate
            } else {
                status = .ready
                seen.insert(draft.duplicateKey)
            }
            candidates.append(ImportCandidate(id: lineNumber, draft: draft, status: status, warnings: warnings, isIncluded: status == .ready))
        }
        return candidates
    }
}

/// Builds the template and export CSV files.
public enum CSVTemplate {
    /// Template with the five specified columns and one example row (fictional data).
    public static func templateRows() -> [[String]] {
        [
            RecipientField.templateFields.map(\.templateHeader),
            ["山田 太郎", "花子", "104-0061", "東京都中央区見本町1-13-3 サンプルハイツ203", "喪中"],
        ]
    }

    /// Header for a full export (all fields, re-importable).
    public static let exportFields: [RecipientField] = [.name, .nameKana, .jointNames, .honorific, .postalCode, .address1, .address2, .memo]

    public static func exportRows(_ drafts: [RecipientDraft]) -> [[String]] {
        var rows = [exportFields.map(\.templateHeader)]
        for draft in drafts {
            rows.append([
                draft.name,
                draft.nameKana,
                draft.jointNames.joined(separator: "・"),
                draft.honorific,
                PostalCode.formatted(draft.postalCode),
                draft.address1,
                draft.address2,
                draft.memo,
            ])
        }
        return rows
    }
}

/// Free tier limits. The values here are product decisions; see AppConstants in the app target
/// for the number shown to users (kept in sync by a unit test).
public enum FreeTier {
    public static let recipientLimit = 10

    /// Number of recipients that may still be added.
    public static func remainingSlots(currentCount: Int, isPro: Bool) -> Int {
        isPro ? Int.max : max(0, recipientLimit - currentCount)
    }
}
