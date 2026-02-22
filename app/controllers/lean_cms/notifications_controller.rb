module LeanCms
  class NotificationsController < ApplicationController
    include LeanCms::Authorization

    def index
      @notifications = current_user.notifications.order(created_at: :desc).page(params[:page]).per(20)
      @unread_count = current_user.notifications.unread.count
    end

    def show
      @notification = current_user.notifications.find(params[:id])
      @notification.mark_as_read! unless @notification.read?
    end

    def mark_as_read
      @notification = current_user.notifications.find(params[:id])
      @notification.mark_as_read!
      redirect_to lean_cms_notifications_path, notice: 'Notification marked as read.'
    end

    def mark_all_as_read
      current_user.notifications.unread.update_all(read_at: Time.current)
      redirect_to lean_cms_notifications_path, notice: 'All notifications marked as read.'
    end
  end
end
