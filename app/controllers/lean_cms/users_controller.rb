module LeanCms
  class UsersController < ApplicationController
    before_action :set_user, only: [:show, :edit, :update, :deactivate, :activate, :send_password_reset]
    after_action :verify_authorized

    def index
      authorize User
      @users = policy_scope(User).includes(:sessions).order(created_at: :desc)
    end

    def show
      authorize @user
    end

    def new
      @user = User.new
      authorize @user
    end

    def create
      @user = User.new(user_params)
      @user.active = false  # Will be activated when they set their password
      @user.password = SecureRandom.hex(32)  # Temporary password, will be replaced
      authorize @user

      if @user.save
        magic_link = MagicLink.create_for_invitation(@user, created_by_ip: request.remote_ip)
        UsersMailer.invitation(@user, magic_link).deliver_later
        redirect_to lean_cms_users_path, notice: "User invited. They will receive an email to set their password."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @user
    end

    def update
      authorize @user

      # Prevent non-super-admins from granting super admin or settings access
      if !current_user.is_super_admin?
        if params[:user][:is_super_admin] == "1" || params[:user][:is_super_admin] == true
          flash[:alert] = "Only super admins can grant super admin privileges."
          render :edit, status: :unprocessable_entity
          return
        end
        if params[:user][:can_access_settings] == "1" || params[:user][:can_access_settings] == true
          flash[:alert] = "Only super admins can grant settings access."
          render :edit, status: :unprocessable_entity
          return
        end
      end

      if @user.update(user_params)
        redirect_to lean_cms_users_path, notice: "User updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def deactivate
      authorize @user

      if @user == current_user
        redirect_to lean_cms_users_path, alert: "You cannot deactivate your own account."
        return
      end

      @user.deactivate!
      redirect_to lean_cms_users_path, notice: "User deactivated."
    end

    def activate
      authorize @user

      # Send a password reset link when activating a previously deactivated user
      magic_link = MagicLink.create_for_password_reset(@user, created_by_ip: request.remote_ip)
      UsersMailer.reactivation(@user, magic_link).deliver_later
      @user.activate!

      redirect_to lean_cms_users_path, notice: "User activated. They will receive an email to set a new password."
    end

    def send_password_reset
      authorize @user

      magic_link = MagicLink.create_for_password_reset(@user, created_by_ip: request.remote_ip)
      UsersMailer.admin_triggered_password_reset(@user, magic_link).deliver_later

      redirect_to lean_cms_users_path, notice: "Password reset email sent to #{@user.email_address}."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      permitted = [:name, :email_address, :can_edit_pages, :can_edit_blog, :can_manage_users]

      # Only super admins can modify these permissions
      if current_user.is_super_admin?
        permitted << :can_access_settings
        permitted << :is_super_admin
      end

      params.require(:user).permit(permitted)
    end
  end
end
