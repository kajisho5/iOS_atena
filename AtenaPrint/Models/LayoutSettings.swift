import AtenaCore
import Foundation
import Observation

/// User layout preferences, stored as JSON in UserDefaults (included in device backups).
nonisolated struct LayoutSettings: Codable, Equatable, Sendable {
    var paper: PaperKind = .hagaki
    var writingMode: WritingMode = .vertical
    var font: AddressFont = .mincho
    var convertDigitsToKanji = true
    var printsSender = false
    var senderID: UUID?
    /// Per-paper printer offsets keyed by `PaperKind.rawValue`.
    var offsets: [String: PrintOffset] = [:]

    init() {}

    func offset(for paper: PaperKind) -> PrintOffset {
        offsets[paper.rawValue] ?? .zero
    }

    mutating func setOffset(_ offset: PrintOffset, for paper: PaperKind) {
        offsets[paper.rawValue] = offset
    }

    // Tolerant decoding so that settings saved by older versions keep working.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        paper = (try? container.decodeIfPresent(PaperKind.self, forKey: .paper)) ?? .hagaki
        writingMode = (try? container.decodeIfPresent(WritingMode.self, forKey: .writingMode)) ?? .vertical
        font = (try? container.decodeIfPresent(AddressFont.self, forKey: .font)) ?? .mincho
        convertDigitsToKanji = (try? container.decodeIfPresent(Bool.self, forKey: .convertDigitsToKanji)) ?? true
        printsSender = (try? container.decodeIfPresent(Bool.self, forKey: .printsSender)) ?? false
        senderID = try? container.decodeIfPresent(UUID.self, forKey: .senderID)
        offsets = (try? container.decodeIfPresent([String: PrintOffset].self, forKey: .offsets)) ?? [:]
    }
}

@Observable
final class LayoutStore {
    private static let storageKey = "layoutSettings.v1"
    @ObservationIgnored private let defaults: UserDefaults

    var settings: LayoutSettings {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(LayoutSettings.self, from: data) {
            settings = decoded
        } else {
            settings = LayoutSettings()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
