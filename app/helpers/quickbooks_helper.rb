# Picking who an invoice goes to: the client's contacts, those who can approve first.
module QuickbooksHelper
  def quickbooks_contact_options(contacts, email_only: false)
    contacts = contacts.select { |contact| contact.email.present? } if email_only
    contacts.sort_by { |contact| [ contact.can_approve? ? 0 : 1, contact.name ] }
            .map { |contact| [ [ contact.name, ("can approve" if contact.can_approve?) ].compact.join(" · "), contact.id ] }
  end

  def quickbooks_default_contact(contacts)
    contacts.find { |contact| contact.can_approve? && contact.email.present? }&.id
  end
end
