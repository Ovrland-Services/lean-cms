module LeanCms
  class PasswordsController < ::ApplicationController
    allow_unauthenticated_access
    before_action :set_user_by_token, only: %i[ edit update ]
    rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to lean_cms_new_password_path, alert: "Try again later." }

    layout "lean_cms/auth"

    def new
    end

    def create
      user_class = LeanCms.user_class.constantize

      if user = user_class.find_by(email_address: params[:email_address])
        LeanCms::PasswordsMailer.reset(user).deliver_later
      end

      redirect_to lean_cms_new_session_path, notice: "Password reset instructions sent (if user with that email address exists)."
    end

    def edit
    end

    def update
      if @user.update(params.permit(:password, :password_confirmation))
        @user.sessions.destroy_all
        redirect_to lean_cms_new_session_path, notice: "Password has been reset."
      else
        redirect_to lean_cms_edit_password_path(params[:token]), alert: "Passwords did not match."
      end
    end

    private

    def set_user_by_token
      @user = LeanCms.user_class.constantize.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to lean_cms_new_password_path, alert: "Password reset link is invalid or has expired."
    end
  end
end
