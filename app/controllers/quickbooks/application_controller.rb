module Quickbooks
  class ApplicationController < ::ApplicationController
    layout "application"

    before_action { head :not_found unless Runwell::Plugins.enabled?(:quickbooks) }

    private
      def set_work = @work = ::Work.find_by_ref!(params[:work_ref])
  end
end
