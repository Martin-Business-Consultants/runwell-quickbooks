module Quickbooks
  # What QuickBooks bills an engagement, set on its Billing tab: a fixed-price engagement's total,
  # or a service's amount per period and how often. Kept here, apart from any agreement: a price
  # written into an agreement is just words there.
  class Price < ::ApplicationRecord
    self.table_name = "quickbooks_prices"

    CADENCES = [ [ "Every week", "weekly" ], [ "Every month", "monthly" ], [ "Every 3 months", "quarterly" ] ].freeze

    belongs_to :engagement, class_name: "::Engagement"
    belongs_to :set_by, class_name: "::User", optional: true

    validates :amount_cents, numericality: { greater_than: 0, message: "must be more than nothing" }
    validates :cadence, inclusion: { in: CADENCES.map(&:last) }, if: -> { engagement&.recurring? }
    validates :engagement_id, uniqueness: true

    def self.for(engagement) = find_by(engagement: engagement)

    # Sets it, and brings a service's recurring invoice into step (in a job, after this commits).
    def self.set!(engagement, amount_cents:, cadence: nil, by: Current.user)
      price = find_or_initialize_by(engagement: engagement)
      price.update!(amount_cents: amount_cents.to_i, cadence: (engagement.recurring? ? cadence.presence || "monthly" : nil), set_by: by)
      engagement.record_event!("quickbooks.price_set", actor: by, payload: { amount: price.label })
      RecurringPushJob.perform_later(engagement.id) if engagement.recurring? && RecurringLink.exists?(engagement: engagement)
      price
    end

    # "$1,200.00", or "$400.00 every 3 months".
    def label = cadence ? "#{Money.format(amount_cents)} #{CADENCES.to_h.invert.fetch(cadence, cadence).downcase}" : Money.format(amount_cents)
  end
end
