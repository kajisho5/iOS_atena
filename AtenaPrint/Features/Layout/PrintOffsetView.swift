import AtenaCore
import SwiftUI

/// Printer feed compensation per paper (S12), in 0.5 mm steps.
struct PrintOffsetView: View {
    @Environment(LayoutStore.self) private var layoutStore
    @Environment(\.printRequestHandler) private var requestPrint
    @State private var paper: PaperKind = .hagaki

    private static let range = -10.0...10.0

    var body: some View {
        Form {
            Section {
                Picker("layout.paper", selection: $paper) {
                    ForEach(PaperKind.allCases) { paper in
                        Text(verbatim: paper.localizedName).tag(paper)
                    }
                }
            }
            Section {
                Stepper(value: offsetBinding(\.y), in: Self.range, step: 0.5) {
                    LabeledContent("offset.vertical") {
                        Text(verbatim: format(offset.y))
                    }
                }
                Stepper(value: offsetBinding(\.x), in: Self.range, step: 0.5) {
                    LabeledContent("offset.horizontal") {
                        Text(verbatim: format(offset.x))
                    }
                }
                Button("offset.reset", role: .destructive) {
                    layoutStore.settings.setOffset(.zero, for: paper)
                }
                .disabled(offset == .zero)
            } footer: {
                Text("offset.footer")
            }
            Section {
                Button {
                    requestPrint(PrintRequest(test: paper))
                } label: {
                    Label("offset.testPrint", systemImage: "printer")
                }
            } footer: {
                Text("offset.testPrint.footer")
            }
        }
        .navigationTitle(Text("settings.offset"))
        .onAppear { paper = layoutStore.settings.paper }
    }

    private var offset: PrintOffset {
        layoutStore.settings.offset(for: paper)
    }

    private func offsetBinding(_ keyPath: WritableKeyPath<PrintOffset, Double>) -> Binding<Double> {
        Binding {
            layoutStore.settings.offset(for: paper)[keyPath: keyPath]
        } set: { newValue in
            var updated = layoutStore.settings.offset(for: paper)
            updated[keyPath: keyPath] = newValue
            layoutStore.settings.setOffset(updated, for: paper)
        }
    }

    /// "+0.5 mm" style text.
    private func format(_ value: Double) -> String {
        let number = value.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always(includingZero: false)))
        return number + " mm"
    }
}
