import Foundation
#if canImport(CoreFoundation)
import CoreFoundation
#endif

/// Text encodings accepted for CSV import.
public enum CSVEncoding: String, CaseIterable, Sendable, Identifiable {
    case utf8
    /// Windows-31J (CP932), the encoding Excel for Japanese Windows uses for "CSV (comma delimited)".
    case shiftJIS

    public var id: String { rawValue }

    public var stringEncoding: String.Encoding {
        switch self {
        case .utf8:
            return .utf8
        case .shiftJIS:
            #if canImport(Darwin)
            // CP932 is a superset of JIS X 0208 Shift_JIS (adds ①, ㈱, NEC/IBM extensions).
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosJapanese.rawValue)))
            #else
            return .shiftJIS
            #endif
        }
    }
}

public enum CSVDecodingError: Error, Equatable, Sendable {
    case empty
    case undecodable
}

/// Decodes raw CSV bytes into text.
public enum CSVTextDecoder {
    private static let utf8BOM: [UInt8] = [0xEF, 0xBB, 0xBF]

    /// Auto-detects the encoding: UTF-8 (with or without BOM) first, then Shift_JIS.
    public static func detectEncoding(of data: Data) -> CSVEncoding? {
        if data.starts(with: utf8BOM) { return .utf8 }
        if String(data: data, encoding: .utf8) != nil { return .utf8 }
        if String(data: data, encoding: CSVEncoding.shiftJIS.stringEncoding) != nil { return .shiftJIS }
        return nil
    }

    /// Decodes with an explicit encoding. A UTF-8 BOM is stripped.
    public static func decode(_ data: Data, as encoding: CSVEncoding) throws -> String {
        guard !data.isEmpty else { throw CSVDecodingError.empty }
        var payload = data
        if encoding == .utf8, data.starts(with: utf8BOM) {
            payload = data.dropFirst(utf8BOM.count)
        }
        guard let text = String(data: payload, encoding: encoding.stringEncoding) else {
            throw CSVDecodingError.undecodable
        }
        return text
    }

    /// Detects the encoding and decodes in one step.
    public static func decode(_ data: Data) throws -> (text: String, encoding: CSVEncoding) {
        guard !data.isEmpty else { throw CSVDecodingError.empty }
        guard let encoding = detectEncoding(of: data) else { throw CSVDecodingError.undecodable }
        return (try decode(data, as: encoding), encoding)
    }
}

/// RFC 4180 CSV parser (comma separated, double-quote escaping, CRLF/LF/CR line breaks,
/// line breaks inside quoted fields).
public enum CSVParser {
    public static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = String()
        var inQuotes = false
        var iterator = Array(text.unicodeScalars)[...]
        var fieldWasQuoted = false

        func endField() {
            row.append(field)
            field = String()
            fieldWasQuoted = false
        }
        func endRow() {
            endField()
            rows.append(row)
            row = []
        }

        while let scalar = iterator.popFirst() {
            if inQuotes {
                if scalar == "\"" {
                    if iterator.first == "\"" {
                        field.unicodeScalars.append("\"")
                        iterator.removeFirst()
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.unicodeScalars.append(scalar)
                }
                continue
            }
            switch scalar {
            case "\"" where field.isEmpty && !fieldWasQuoted:
                inQuotes = true
                fieldWasQuoted = true
            case ",":
                endField()
            case "\r":
                if iterator.first == "\n" { iterator.removeFirst() }
                endRow()
            case "\n":
                endRow()
            default:
                field.unicodeScalars.append(scalar)
            }
        }
        if !field.isEmpty || !row.isEmpty || fieldWasQuoted {
            endRow()
        }
        // Drop blank lines (a single empty field) such as a trailing newline in the middle of a file.
        return rows.filter { !($0.count == 1 && $0[0].isEmpty) }
    }
}

/// CSV writer producing Excel-friendly output (UTF-8 with BOM, CRLF line endings).
public enum CSVWriter {
    /// Leading characters that spreadsheet apps may evaluate as a formula.
    static let formulaTriggers: Set<Character> = ["=", "+", "@", "\t", "\r"]

    public static func string(from rows: [[String]]) -> String {
        rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    /// UTF-8 bytes with BOM so that Excel detects the encoding.
    public static func data(from rows: [[String]]) -> Data {
        Data([0xEF, 0xBB, 0xBF]) + Data(string(from: rows).utf8)
    }

    /// Quotes a field when required and neutralizes formula injection by prefixing an apostrophe.
    static func escape(_ field: String) -> String {
        var value = field
        if let first = value.first, formulaTriggers.contains(first) {
            value = "'" + value
        }
        let needsQuotes = value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" })
            || value.hasPrefix(" ") || value.hasSuffix(" ")
        guard needsQuotes else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Reverses the formula-injection guard on import ("'=..." → "=...").
    public static func unescapeFormulaGuard(_ field: String) -> String {
        guard field.hasPrefix("'"), let second = field.dropFirst().first, formulaTriggers.contains(second) else {
            return field
        }
        return String(field.dropFirst())
    }
}
