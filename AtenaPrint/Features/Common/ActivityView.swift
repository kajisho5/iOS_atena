import SwiftUI
import UIKit

/// System share sheet for already-generated files.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// A CSV file offered through `ShareLink`.
nonisolated struct CSVFile: Transferable, Sendable {
    let data: Data
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CSVExport", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(file.fileName)
            try file.data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
