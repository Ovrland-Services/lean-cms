module LeanCms
  class SessionsController < ::ApplicationController
    allow_unauthenticated_access only: %i[ new create ]
    rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to lean_cms_new_session_path, alert: "Try again later." }

    layout "lean_cms/auth"

    def new
      redirect_to after_authentication_url if authenticated?
    end

    def create
      user_class = LeanCms.user_class.constantize

      if user = user_class.authenticate_by(params.permit(:email_address, :password))
        unless user.active?
          redirect_to lean_cms_new_session_path, alert: "Your account has been deactivated. Please contact an administrator."
          return
        end

        start_new_session_for user
        user.record_login!

        if user.must_change_password?
          magic_link = LeanCms::MagicLink.create_for_password_reset(user)
          redirect_to lean_cms_password_setup_path(token: magic_link.token), notice: "Please set a new password."
        else
          redirect_to after_authentication_url
        end
      else
        redirect_to lean_cms_new_session_path, alert: "Try another email address or password."
      end
    end

    def destroy
      terminate_session
      redirect_to lean_cms_new_session_path, status: :see_other
    end

    private

    def after_authentication_url
      if LeanCms::Current.user&.has_any_cms_permission?
        lean_cms_root_path
      else
        session.delete(:return_to_after_authenticating) || "/"
      end
    end
  end
end
