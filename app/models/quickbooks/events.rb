module Quickbooks
  # What the core's events set off here ("event.runwell"): closing a work order sends its
  # armed balance; closing a service brings its recurring invoice into step (a new price does
  # too, from Price.set!). The work runs in jobs, after the core's write has committed.
  module Events
    def self.handle(event)
      return unless Runwell::Plugins.enabled?(:quickbooks) && event.subject.is_a?(::Work)

      work = event.subject
      case event.kind
      when "work.closed"
        BalanceJob.perform_later(work.id) if BillingPlan.waiting.exists?(work: work)
        RecurringPushJob.perform_later(work.id) if RecurringLink.exists?(work: work)
      end
    end
  end
end
