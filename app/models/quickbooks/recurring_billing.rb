module Quickbooks
  # A service's recurring invoice in QuickBooks: made from the price set on its Billing tab
  # (Price), or an existing template linked to it, then kept in step when that price changes and
  # when the service closes. QuickBooks sends each invoice itself, to the contact chosen here.
  class RecurringBilling
    def initialize(work, connection = Connection.current)
      @work, @connection = work, connection
    end

    attr_reader :work

    def link = RecurringLink.find_by(work: work)

    # The Stripe plugin keeps one billing per service; QuickBooks never bills one it holds.
    def billed_by_stripe?
      return false unless Runwell::Plugins.enabled?(:stripe_billing) && work.respond_to?(:stripe_subscription)

      subscription = work.stripe_subscription
      subscription.present? && subscription.live? && subscription.stripe?
    end
    def customer = Customer.for(work.client)

    def blocker
      return "QuickBooks can’t bill yet: #{@connection&.blocker || "it isn’t set up"}." unless @connection&.can_invoice?
      return "Only a service bills on a schedule; invoice fixed-price work instead." unless work.recurring?
      return "This service is billed through Stripe, so QuickBooks won’t bill it too." if billed_by_stripe?
      return "Set what to bill first: the amount per period and how often." unless Price.for(work)
      return "#{work.client.name} isn’t linked to a QuickBooks customer. Link it on the client’s page." unless customer

      nil
    end

    # A new template billing the price per period on its cadence from start_on.
    def create!(contact:, start_on:, actor: Current.user)
      raise ArgumentError, blocker if blocker
      raise ArgumentError, "This service already has a recurring invoice." if link
      raise ArgumentError, "Choose a contact with an email address for the invoices." if contact&.email.blank?

      wanted = RecurringLink.new(work: work).expected
      template = api.save_recurring_template(
        "RecurringInfo" => { "Name" => "#{work.ref} #{work.title}".truncate(100), "RecurType" => "Automated", "Active" => true,
          "ScheduleInfo" => schedule(start_on.to_date, wanted) },
        "CustomerRef" => { "value" => customer.qbo_id }, "Line" => [ Lines.line(line_text, wanted[:amount_cents]) ],
        "BillEmail" => { "Address" => contact.email }, "EmailStatus" => "NeedToSend", "PrivateNote" => "#{Invoice::MEMO}#{work.ref}",
        "AllowOnlineACHPayment" => true, "AllowOnlineCreditCardPayment" => true
      )
      record_link(template, contact: contact, event: "quickbooks.recurring_created", actor: actor)
    end

    # An existing template, when it bills this client's customer.
    def link!(qbo_id, actor: Current.user)
      raise ArgumentError, blocker if blocker
      raise ArgumentError, "This service already has a recurring invoice." if link

      template = api.recurring_template(qbo_id.to_s.strip) or raise ArgumentError, "QuickBooks has no recurring invoice #{qbo_id}."
      unless template.dig("CustomerRef", "value") == customer.qbo_id
        raise ArgumentError, "That recurring invoice bills #{template.dig("CustomerRef", "name")}, not #{work.client.name}."
      end
      record_link(template, event: "quickbooks.recurring_linked", actor: actor)
    end

    # Makes QuickBooks match the price set here: its amount and cadence, and stopped once the
    # service is closed. Returns the link.
    def push!(actor: nil)
      link = self.link or return
      wanted = link.expected
      template = api.recurring_template(link.qbo_id) or raise Api::Error, "QuickBooks no longer has recurring invoice #{link.qbo_id}."
      template["Line"] = [ Lines.line(line_text, wanted[:amount_cents]) ]
      template["RecurringInfo"]["Active"] = wanted[:active]
      info = template["RecurringInfo"]["ScheduleInfo"] ||= {}
      info.merge!(schedule(Date.parse(info["NextDate"] || info["StartDate"] || Date.current.iso8601), wanted).except("StartDate"))
      saved = api.save_recurring_template(template)
      link.observe!(saved)
      link.update!(pushed_at: Time.current)
      change = wanted[:active] ? "quickbooks.recurring_updated" : "quickbooks.recurring_stopped"
      work.record_event!(change, actor: actor, payload: { amount: Money.format(wanted[:amount_cents]), schedule: link.schedule_label })
      link
    end

    private
      def api = @api ||= Api.new(@connection)
      def line_text = "#{work.ref} #{work.title}"

      def schedule(start_on, wanted)
        info = { "StartDate" => start_on.iso8601, "IntervalType" => wanted[:interval_type], "NumInterval" => wanted[:num_interval] }
        wanted[:interval_type] == "Weekly" ? info.merge("DayOfWeek" => start_on.strftime("%A")) : info.merge("DayOfMonth" => [ start_on.day, 28 ].min)
      end

      def record_link(template, event:, actor:, contact: nil)
        link = RecurringLink.create!(work: work, contact: contact, qbo_id: template["Id"])
        link.observe!(template)
        work.record_event!(event, actor: actor, payload: { name: link.name, amount: Money.format(link.amount_cents), schedule: link.schedule_label })
        link
      end
  end
end
