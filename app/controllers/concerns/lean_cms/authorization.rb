module LeanCms
  module Authorization
    extend ActiveSupport::Concern

    included do
      before_action :require_cms_access
      helper_method :current_user
    end

    private

    # Base access check - user must have at least one CMS permission
    def require_cms_access
      unless LeanCms::Current.user&.has_any_cms_permission?
        redirect_to root_path, alert: "You do not have access to the CMS."
      end
    end

    # Specific permission checks for controllers that need them
    def require_page_editing
      unless LeanCms::Current.user&.can_edit_pages?
        redirect_to lean_cms_root_path, alert: "You do not have permission to edit pages."
      end
    end

    def require_blog_editing
      unless LeanCms::Current.user&.can_edit_blog?
        redirect_to lean_cms_root_path, alert: "You do not have permission to edit blog posts."
      end
    end

    def require_user_management
      unless LeanCms::Current.user&.can_manage_users?
        redirect_to lean_cms_root_path, alert: "You do not have permission to manage users."
      end
    end

    def require_settings_access
      unless LeanCms::Current.user&.can_access_settings?
        redirect_to lean_cms_root_path, alert: "You do not have permission to access settings."
      end
    end

    # Check if current user can edit a specific record
    def can_edit?(record)
      return true if LeanCms::Current.user&.is_super_admin?
      return true if record.respond_to?(:author) && record.author == LeanCms::Current.user
      false
    end

    def set_paper_trail_whodunnit
      PaperTrail.request.whodunnit = LeanCms::Current.user&.id
    end

    # Helper method for views
    def current_user
      LeanCms::Current.user
    end
  end
end
