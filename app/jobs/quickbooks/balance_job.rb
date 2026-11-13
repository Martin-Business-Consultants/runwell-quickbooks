module Quickbooks
  # A closed work order's balance, armed when its deposit was sent.
  class BalanceJob < ::ApplicationJob
    queue_as :default

    def perform(work_id)
      work = ::Work.find(work_id)
      Current.source = "quickbooks"
      WorkOrderBilling.new(work).balance!
    rescue Api::Error, ArgumentError => e
      BillingPlan.find_by(work_id: work_id)&.update!(last_error: e.message)
      work&.record_event!("quickbooks.balance_failed", source: "quickbooks", payload: { error: e.message.truncate(200) })
    end
  end
end
