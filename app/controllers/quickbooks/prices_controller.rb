# What QuickBooks bills an engagement: a fixed-price total, or a service's amount per period.
module Quickbooks
  class PricesController < ApplicationController
    require_permission :manage_billing
    agent_tool :set_quickbooks_price, on: :update, title: "Set what QuickBooks bills an engagement",
      description: "amount_cents: whole cents; for fixed-price work the total to invoice, for a service the amount per period. cadence (services only): weekly, monthly or quarterly. A linked recurring invoice is brought into step.",
      params: { price: { amount_cents: "integer!", cadence: %w[weekly monthly quarterly] } }

    before_action :set_engagement

    def update
      details = params.expect(price: %i[amount_cents cadence])
      price = Price.set!(@engagement, amount_cents: details[:amount_cents], cadence: details[:cadence])
      redirect_back fallback_location: engagement_path(@engagement, tab: "plugin-quickbooks"), notice: "QuickBooks bills #{@engagement.ref} #{price.label}."
    rescue ActiveRecord::RecordInvalid => error
      redirect_back fallback_location: engagement_path(@engagement, tab: "plugin-quickbooks"), alert: error.record.errors.full_messages.to_sentence
    end
  end
end
