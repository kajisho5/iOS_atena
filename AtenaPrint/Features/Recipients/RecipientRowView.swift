import AtenaCore
import SwiftUI

struct RecipientRowView: View {
    let recipient: Recipient
    let group: RecipientGroup?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        layout {
            VStack(alignment: .leading, spacing: 4) {
                nameLine
                addressLine
                if !recipient.memo.isEmpty {
                    Text(verbatim: recipient.memo)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
            if let record = recipient.lastPrint(in: group) {
                PrintedBadge(date: record.printedAt)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var nameLine: some View {
        (Text(verbatim: recipient.name).font(.headline)
            + Text(verbatim: " ") + Text(verbatim: recipient.honorific).font(.subheadline)
            + (recipient.jointNames.isEmpty ? Text(verbatim: "") : Text(verbatim: "・" + recipient.jointNames.joined(separator: "・")).font(.subheadline).foregroundColor(Color.secondaryText)))
    }

    private var addressLine: some View {
        let postal = recipient.postalCode.isEmpty ? "" : "〒" + PostalCode.formatted(recipient.postalCode) + " "
        return Text(verbatim: postal + recipient.address1)
            .font(.subheadline)
            .foregroundStyle(Color.secondaryText)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
    }
}

/// "印刷済み M/d" with an icon so the state is not conveyed by color alone.
struct PrintedBadge: View {
    let date: Date

    var body: some View {
        let day = date.formatted(.dateTime.month(.defaultDigits).day())
        return Label {
            Text("badge.printed \(day)")
        } icon: {
            Image(systemName: "checkmark")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.successText)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.quaternary, in: Capsule())
    }
}
