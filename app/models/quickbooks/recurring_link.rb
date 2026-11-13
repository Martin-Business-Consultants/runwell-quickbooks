module Quickbooks
  # A service tied to a QuickBooks recurring invoice template, so what Runwell says the service
  # costs (its Price) is what QuickBooks bills. Runwell keeps the template in step (a new price
  # changes it, closing the service stops it); the sync flags a template someone changed in
  # QuickBooks so it no longer matches.
  class RecurringLink < ::ApplicationRecord
    self.table_name = "quickbooks_recurring_links"

    CADENCES = { "weekly" => [ "Weekly", 1 ], "monthly" => [ "Monthly", 1 ], "quarterly" => [ "Monthly", 3 ] }.freeze

    belongs_to :work, class_name: "::Work"
    belongs_to :contact, class_name: "::Contact", optional: true

    validates :qbo_id, presence: true
    validates :work_id, uniqueness: { message: "already has a recurring invoice" }

    scope :drifting, -> { where.not(drift: nil) }

    def in_sync? = drift.nil?
    UNITS = { "Daily" => "day", "Weekly" => "week", "Monthly" => "month", "Yearly" => "year" }.freeze

    # "every month", "every 3 months".
    def schedule_label
      unit = UNITS[interval_type] or return nil
      num_interval.to_i > 1 ? "every #{num_interval} #{unit.pluralize}" : "every #{unit}"
    end
    def label = "#{work.ref} recurring invoice"

    # What QuickBooks should hold for this service: its price per period and cadence, active
    # while the service is open.
    def expected
      price = Price.for(work)
      interval, every = CADENCES.fetch(price&.cadence.to_s, CADENCES["monthly"])
      { amount_cents: price&.amount_cents.to_i, interval_type: interval, num_interval: every, active: !work.closed? }
    end

    # Remembers what QuickBooks said and whether it matches the price set here.
    def observe!(template)
      schedule = template.dig("RecurringInfo", "ScheduleInfo") || {}
      update!(sync_token: template["SyncToken"], name: template.dig("RecurringInfo", "Name"),
        amount_cents: (template["TotalAmt"].to_f * 100).round, interval_type: schedule["IntervalType"],
        num_interval: schedule["NumInterval"], active: template.dig("RecurringInfo", "Active") != false,
        next_on: schedule["NextDate"].presence, synced_at: Time.current, drift: nil)
      update!(drift: drift_from(expected))
    end

    private
      def drift_from(wanted)
        differences = []
        differences << "QuickBooks bills #{Money.format(amount_cents)}, Runwell says #{Money.format(wanted[:amount_cents])}" if amount_cents != wanted[:amount_cents]
        differences << "QuickBooks bills #{schedule_label}, Runwell says #{Price.for(work)&.cadence || "monthly"}" if [ interval_type, num_interval.to_i ] != [ wanted[:interval_type], wanted[:num_interval] ]
        differences << (active ? "the service is closed but QuickBooks still bills it" : "QuickBooks stopped billing an open service") if active != wanted[:active]
        differences.join("; ").presence
      end
  end
end
