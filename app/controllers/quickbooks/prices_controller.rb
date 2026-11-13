# What QuickBooks bills a piece of work: a fixed-price total, or a service's amount per period.
module Quickbooks
  class PricesController < ApplicationController
    require_permission :manage_billing
    agent_tool :set_quickbooks_price, on: :update, title: "Set what QuickBooks bills a piece of work",
      description: "amount_cents: whole cents; for fixed-price work the total to invoice, for a service the amount per period. cadence (services only): weekly, monthly or quarterly. A linked recurring invoice is brought into step.",
      params: { price: { amount_cents: "integer!", cadence: %w[weekly monthly quarterly] } }

    before_action :set_work

    def update
      details = params.expect(price: %i[amount_cents cadence])
      price = Price.set!(@work, amount_cents: details[:amount_cents], cadence: details[:cadence])
      redirect_back fallback_location: work_path(@work, tab: "plugin-quickbooks"), notice: "QuickBooks bills #{@work.ref} #{price.label}."
    rescue ActiveRecord::RecordInvalid => error
      redirect_back fallback_location: work_path(@work, tab: "plugin-quickbooks"), alert: error.record.errors.full_messages.to_sentence
    end
  end
end
