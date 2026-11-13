module Quickbooks
  # A Runwell plugin: QuickBooks Online for money, which the core never holds. Clients link to
  # customers; each piece of work has a price set here (Price); services keep a recurring invoice
  # template in step with it; fixed-price work is invoiced in full, or a deposit now and the balance on close,
  # each sent by QuickBooks with its pay button. Invoices and payments are mirrored for the
  # portal and for the Reporting plugin. It owns its tables and extends the core only through
  # Runwell::Plugins, load hooks and "event.runwell".
  class Engine < ::Rails::Engine

    initializer "quickbooks.routes" do |app|
      app.routes.append do
        scope "quickbooks", module: "quickbooks", as: "quickbooks" do
          resource :settings, only: %i[show update destroy]
          resource :authorization, only: %i[create show]
          resource :sync, only: :create
          resources :invoices, only: :index
          resources :clients, only: [] do
            resource :customer, only: %i[create destroy]
          end
          resources :works, path: "work", param: :ref, only: [] do
            resources :invoices, only: :create
            resource :recurring, only: %i[create update destroy], controller: "recurring"
            resource :price, only: :update
          end
        end
      end
    end

    initializer "quickbooks.events" do
      ActiveSupport::Notifications.subscribe("event.runwell") { |*, payload| Quickbooks::Events.handle(payload[:event]) }
    end

    initializer "quickbooks.models" do
      ActiveSupport.on_load(:runwell_client) do
        has_one :quickbooks_customer, class_name: "Quickbooks::Customer", dependent: :destroy
        has_many :quickbooks_invoices, class_name: "Quickbooks::Invoice", dependent: :destroy
      end
      ActiveSupport.on_load(:runwell_work) do
        has_many :quickbooks_invoices, class_name: "Quickbooks::Invoice", dependent: :nullify
        has_one :quickbooks_recurring_link, class_name: "Quickbooks::RecurringLink", dependent: :destroy
        has_one :quickbooks_billing_plan, class_name: "Quickbooks::BillingPlan", dependent: :destroy
        has_one :quickbooks_price, class_name: "Quickbooks::Price", dependent: :destroy
      end
    end

    config.to_prepare do
      Runwell::Plugins.register :quickbooks, name: "QuickBooks", version: Quickbooks::VERSION, author: "Runwell",
        requires: ">= 6.0.0", homepage: "https://github.com/Martin-Business-Consultants/runwell-quickbooks",
        description: "Money through QuickBooks Online: set what each piece of work costs, keep each service’s recurring invoice in step with it, invoice work orders in full or as a deposit and balance with a pay link, and show clients their invoices in the portal."
      Runwell::Plugins.settings :quickbooks, "QuickBooks", -> { quickbooks_settings_path }
      Runwell::Plugins.stylesheet :quickbooks, "quickbooks/quickbooks"
      Runwell::Plugins.permission :quickbooks, :manage_billing, name: "Invoice clients and link recurring billing", roles: %w[owner manager]
      Runwell::Plugins.slot :client_panel, :quickbooks, "quickbooks/slots/client_panel"
      Runwell::Plugins.slot :work_panel, :quickbooks, "quickbooks/slots/work_panel"
      Runwell::Plugins.slot :portal_home, :quickbooks, "quickbooks/slots/portal_home"
      Runwell::Plugins.slot :portal_work_panel, :quickbooks, "quickbooks/slots/portal_work_panel"
      Runwell::Plugins.nightly :quickbooks, -> { Quickbooks::SyncJob.perform_later }
    end
  end
end
