module LeanCms
  class ActivityController < ApplicationController
    skip_before_action :check_content_lock
    before_action :require_settings_access

    def index
      @versions = PaperTrail::Version
        .order(created_at: :desc)
        .page(params[:page])
        .per(20)

      @versions = @versions.where(item_type: params[:item_type]) if params[:item_type].present?
      @versions = @versions.where(whodunnit: params[:whodunnit]) if params[:whodunnit].present?
    end
  end
end
