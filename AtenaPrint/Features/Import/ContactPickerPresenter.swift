import AtenaCore
import Contacts
import ContactsUI
import SwiftUI

/// Presents `CNContactPickerViewController` (multiple selection) from a hidden host controller.
/// The picker runs out of process, so the app never needs Contacts authorization.
struct ContactPickerPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onSelect: ([CNContact]) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, host.presentedViewController == nil else { return }
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        host.present(picker, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, @preconcurrency CNContactPickerDelegate {
        var parent: ContactPickerPresenter

        init(parent: ContactPickerPresenter) {
            self.parent = parent
        }

        // Implementing the plural variant enables multiple selection in the picker.
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.isPresented = false
            parent.onSelect(contacts)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
        }
    }
}

/// Converts a contact into a recipient draft (Japanese name order: family name first).
enum ContactDraftMapper {
    static func draft(from contact: CNContact) -> RecipientDraft? {
        func value(_ key: String, _ read: () -> String) -> String {
            contact.isKeyAvailable(key) ? TextNormalization.trimmed(read()) : ""
        }
        let family = value(CNContactFamilyNameKey) { contact.familyName }
        let given = value(CNContactGivenNameKey) { contact.givenName }
        let organization = value(CNContactOrganizationNameKey) { contact.organizationName }
        let phoneticFamily = value(CNContactPhoneticFamilyNameKey) { contact.phoneticFamilyName }
        let phoneticGiven = value(CNContactPhoneticGivenNameKey) { contact.phoneticGivenName }

        var draft = RecipientDraft()
        let personName = [family, given].filter { !$0.isEmpty }.joined(separator: " ")
        if personName.isEmpty {
            guard !organization.isEmpty else { return nil }
            draft.name = organization
            draft.honorific = "御中"
        } else {
            draft.name = personName
        }
        draft.nameKana = [phoneticFamily, phoneticGiven].filter { !$0.isEmpty }.joined(separator: " ")

        if contact.isKeyAvailable(CNContactPostalAddressesKey), let address = preferredAddress(contact.postalAddresses) {
            draft.postalCode = PostalCode.digitsOnly(address.postalCode)
            let streetLines = address.street.split(whereSeparator: \.isNewline).map { TextNormalization.trimmed(String($0)) }
            let head = [address.state, address.subAdministrativeArea, address.city, address.subLocality, streetLines.first ?? ""]
                .map(TextNormalization.trimmed)
                .filter { !$0.isEmpty }
                .joined()
            draft.address1 = head
            draft.address2 = streetLines.dropFirst().joined(separator: " ")
        }
        return draft
    }

    /// Prefers the home address, then the first one.
    private static func preferredAddress(_ addresses: [CNLabeledValue<CNPostalAddress>]) -> CNPostalAddress? {
        (addresses.first { $0.label == CNLabelHome } ?? addresses.first)?.value
    }
}
