# A service's recurring invoice in QuickBooks: create one from its price or link an
# existing one (create), bring it into step now (update), or let go of it (destroy).
module Quickbooks
  class RecurringController < ApplicationController
    require_permission :manage_billing
    agent_tool :link_recurring_invoice, on: :create, title: "Give a service a recurring invoice in QuickBooks",
      description: "With qbo_id, links an existing recurring invoice (it must bill this client’s customer). Without, creates one billing the work's price (set_quickbooks_price) on its cadence from start_on, which QuickBooks emails to contact_id each period.",
      params: { recurring: { qbo_id: "string", start_on: "date", contact_id: "integer" } },
      confirm: "QuickBooks will bill the client on this schedule and email each invoice, with a pay link, to the contact."
    agent_tool :sync_recurring_invoice, on: :update, title: "Bring a service’s recurring invoice into step with its price now",
      description: "Sets QuickBooks to the price’s amount and cadence, and stops it if the service is closed. It already happens when the price changes and on close."
    agent_tool :unlink_recurring_invoice, on: :destroy, title: "Unlink a service’s recurring invoice",
      description: "Only unlinks: QuickBooks keeps billing until it’s stopped there or the service is closed first."

    before_action :set_work

    def create
      attributes = params.expect(recurring: %i[qbo_id start_on contact_id])
      billing = RecurringBilling.new(@work)
      link = if attributes[:qbo_id].present?
        billing.link!(attributes[:qbo_id])
      else
        billing.create!(contact: @work.client.contacts.find_by(id: attributes[:contact_id]), start_on: attributes[:start_on].presence || Date.current.next_month.beginning_of_month)
      end
      redirect_to work_path(@work), notice: "#{link.name} bills #{Money.format(link.amount_cents)} #{link.schedule_label}#{link.in_sync? ? "" : ". It doesn’t match the price set here: #{link.drift}"}."
    rescue ArgumentError, Api::Error => e
      redirect_to work_path(@work), alert: e.message
    end

    def update
      link = RecurringBilling.new(@work).push! or return redirect_to(work_path(@work), alert: "This service has no recurring invoice.")
      redirect_to work_path(@work), notice: "QuickBooks bills #{Money.format(link.amount_cents)} #{link.schedule_label}#{link.active ? "" : " and has stopped"}."
    rescue ArgumentError, Api::Error => e
      redirect_to work_path(@work), alert: e.message
    end

    def destroy
      RecurringLink.find_by(work: @work)&.destroy!
      @work.record_event!("quickbooks.recurring_unlinked")
      redirect_to work_path(@work), notice: "Unlinked. QuickBooks keeps billing it until it’s stopped there."
    end
  end
end
