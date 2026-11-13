module Quickbooks
  # Brings a service's recurring invoice into step with its price.
  class RecurringPushJob < ::ApplicationJob
    queue_as :default

    def perform(work_id)
      work = ::Work.find(work_id)
      Current.source = "quickbooks"
      RecurringBilling.new(work).push!
    rescue Api::Error, ArgumentError => e
      RecurringLink.find_by(work_id: work_id)&.update!(drift: "Couldn’t update QuickBooks: #{e.message}".truncate(250))
    end
  end
end
