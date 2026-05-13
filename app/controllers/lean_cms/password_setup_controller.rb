module LeanCms
  class PasswordSetupController < ::ApplicationController
    allow_unauthenticated_access
    before_action :set_magic_link
    before_action :ensure_link_valid

    layout "lean_cms/auth"

    def show
      @user = @magic_link.user
    end

    def update
      @user = @magic_link.user

      if params[:password].blank?
        flash.now[:alert] = "Password cannot be blank."
        render :show, status: :unprocessable_entity
        return
      end

      if params[:password] != params[:password_confirmation]
        flash.now[:alert] = "Passwords do not match."
        render :show, status: :unprocessable_entity
        return
      end

      if params[:password].length < 8
        flash.now[:alert] = "Password must be at least 8 characters."
        render :show, status: :unprocessable_entity
        return
      end

      @user.password = params[:password]
      @user.password_confirmation = params[:password_confirmation]
      @user.active = true
      @user.must_change_password = false

      if @user.save
        @magic_link.mark_as_used!(request.remote_ip)
        LeanCms::Session.where(user: @user).destroy_all
        redirect_to lean_cms_new_session_path, notice: "Password set successfully. Please log in."
      else
        flash.now[:alert] = @user.errors.full_messages.join(", ")
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_magic_link
      @magic_link = LeanCms::MagicLink.find_by(token: params[:token])
    end

    def ensure_link_valid
      if @magic_link.nil?
        redirect_to lean_cms_new_session_path, alert: "Invalid link."
      elsif @magic_link.expired?
        redirect_to lean_cms_new_session_path, alert: "This link has expired. Please request a new one."
      elsif @magic_link.used?
        redirect_to lean_cms_new_session_path, alert: "This link has already been used."
      end
    end
  end
end
