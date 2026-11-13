module Quickbooks
  # What QuickBooks bills a piece of work, set on its Billing tab: a fixed-price work's total,
  # or a service's amount per period and how often. Kept here, apart from any agreement: a price
  # written into an agreement is just words there.
  class Price < ::ApplicationRecord
    self.table_name = "quickbooks_prices"

    CADENCES = [ [ "Every week", "weekly" ], [ "Every month", "monthly" ], [ "Every 3 months", "quarterly" ] ].freeze

    belongs_to :work, class_name: "::Work"
    belongs_to :set_by, class_name: "::User", optional: true

    validates :amount_cents, numericality: { greater_than: 0, message: "must be more than nothing" }
    validates :cadence, inclusion: { in: CADENCES.map(&:last) }, if: -> { work&.recurring? }
    validates :work_id, uniqueness: true

    def self.for(work) = find_by(work: work)

    # Sets it, and brings a service's recurring invoice into step (in a job, after this commits).
    def self.set!(work, amount_cents:, cadence: nil, by: Current.user)
      price = find_or_initialize_by(work: work)
      price.update!(amount_cents: amount_cents.to_i, cadence: (work.recurring? ? cadence.presence || "monthly" : nil), set_by: by)
      work.record_event!("quickbooks.price_set", actor: by, payload: { amount: price.label })
      RecurringPushJob.perform_later(work.id) if work.recurring? && RecurringLink.exists?(work: work)
      price
    end

    # "$1,200.00", or "$400.00 every 3 months".
    def label = cadence ? "#{Money.format(amount_cents)} #{CADENCES.to_h.invert.fetch(cadence, cadence).downcase}" : Money.format(amount_cents)
  end
end
