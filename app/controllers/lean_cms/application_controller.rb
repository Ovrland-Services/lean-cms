module LeanCms
  class ApplicationController < ::ApplicationController
    # Pundit is included here so the gem's admin controllers (UsersController
    # most prominently) can call `authorize` / `policy_scope` without
    # requiring the host's ApplicationController to include it. Hosts that
    # want Pundit available in their own non-CMS controllers should still
    # `include Pundit::Authorization` in their own ApplicationController.
    include Pundit::Authorization

    include LeanCms::Authorization

    layout 'lean_cms/application'

    before_action :set_paper_trail_whodunnit
    before_action :check_content_lock, only: [:create, :update]

    private

    def can_edit?(resource)
      return true if current_user&.is_super_admin?
      return true if resource.respond_to?(:author) && resource.author_id == current_user&.id
      false
    end
    helper_method :can_edit?

    def content_locked?
      LeanCms::Setting.content_locked?
    end
    helper_method :content_locked?

    def content_lock_info
      LeanCms::Setting.content_lock_info
    end
    helper_method :content_lock_info

    def check_content_lock
      return unless content_locked?

      lock_info = content_lock_info
      message = "Content editing is temporarily locked: #{lock_info[:reason]}"

      respond_to do |format|
        format.html { redirect_back fallback_location: lean_cms_dashboard_path, alert: message }
        format.json { render json: { error: message, locked: true }, status: :locked }
      end
    end
  end
end
