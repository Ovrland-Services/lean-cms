module LeanCms
  class NotificationSettingsController < ApplicationController
    include LeanCms::Authorization
    skip_before_action :check_content_lock
    before_action :require_settings_access

    def edit
      @settings = NotificationSetting.instance
    end

    def update
      @settings = NotificationSetting.instance

      # Update basic toggles
      @settings.email_enabled = params[:email_enabled] == '1'
      @settings.sms_enabled = params[:sms_enabled] == '1'
      @settings.in_app_enabled = params[:in_app_enabled] == '1'
      @settings.email_provider = params[:email_provider] || 'none'

      # Update email credentials (only if provider is set and new value provided)
      # Password fields will be empty if not changed, so only update if present
      if params[:email_provider] == 'sendgrid'
        @settings.sendgrid_api_key = params[:sendgrid_api_key] if params[:sendgrid_api_key].present?
        @settings.mailgun_api_key = nil
        @settings.mailgun_domain = nil
      elsif params[:email_provider] == 'mailgun'
        @settings.mailgun_api_key = params[:mailgun_api_key] if params[:mailgun_api_key].present?
        @settings.mailgun_domain = params[:mailgun_domain] if params[:mailgun_domain].present?
        @settings.sendgrid_api_key = nil
      else
        # Only clear if switching away from a provider
        @settings.sendgrid_api_key = nil if @settings.email_provider == 'sendgrid'
        @settings.mailgun_api_key = nil if @settings.email_provider == 'mailgun'
        @settings.mailgun_domain = nil if @settings.email_provider == 'mailgun'
      end

      # Update SMS credentials
      if params[:sms_enabled] == '1'
        @settings.twilio_account_sid = params[:twilio_account_sid] if params[:twilio_account_sid].present?
        @settings.twilio_auth_token = params[:twilio_auth_token] if params[:twilio_auth_token].present?
        @settings.twilio_from_number = params[:twilio_from_number] if params[:twilio_from_number].present?
      else
        @settings.twilio_account_sid = nil
        @settings.twilio_auth_token = nil
        @settings.twilio_from_number = nil
      end

      # Update notification recipients
      if params[:notification_emails].present?
        emails = params[:notification_emails].split(',').map(&:strip).reject(&:blank?)
        @settings.notification_email_list = emails
      end

      if params[:notification_phones].present?
        phones = params[:notification_phones].split(',').map(&:strip).reject(&:blank?)
        @settings.notification_phone_list = phones
      end

      if @settings.save
        redirect_to edit_lean_cms_notification_settings_path, notice: 'Notification settings updated successfully.'
      else
        flash[:alert] = @settings.errors.full_messages.join(', ')
        render :edit, status: :unprocessable_entity
      end
    end

    def test_email
      @settings = NotificationSetting.instance

      unless @settings.email_enabled? && @settings.email_provider != 'none'
        flash[:alert] = 'Email notifications must be enabled and configured before testing.'
        redirect_to edit_lean_cms_notification_settings_path
        return
      end

      # Create a test form submission
      test_submission = LeanCms::FormSubmission.create!(
        form_type: 'contact',
        name: 'Test User',
        email: 'test@example.com',
        phone: '(555) 555-5555',
        company_name: 'Test Company',
        city: 'Test City',
        state: 'WI',
        zip: '54311',
        message: 'This is a test notification from the CMS settings page.',
        ip_address: request.remote_ip,
        status: :new_submission
      )

      # Trigger notification
      begin
        ContactFormNotifier.with(submission: test_submission).deliver_later(User.where(can_access_settings: true).limit(1))
        flash[:notice] = 'Test email notification sent successfully!'
      rescue StandardError => e
        Rails.logger.error "Test email error: #{e.message}"
        flash[:alert] = "Failed to send test email: #{e.message}"
      ensure
        # Clean up test submission
        test_submission.destroy
      end

      redirect_to edit_lean_cms_notification_settings_path
    end

    def test_sms
      @settings = NotificationSetting.instance

      unless @settings.sms_enabled?
        flash[:alert] = 'SMS notifications must be enabled before testing.'
        redirect_to edit_lean_cms_notification_settings_path
        return
      end

      # Create a test form submission
      test_submission = LeanCms::FormSubmission.create!(
        form_type: 'contact',
        name: 'Test User',
        email: 'test@example.com',
        phone: '(555) 555-5555',
        company_name: 'Test Company',
        city: 'Test City',
        state: 'WI',
        zip: '54311',
        message: 'This is a test SMS notification from the CMS settings page.',
        ip_address: request.remote_ip,
        status: :new_submission
      )

      # Trigger notification
      begin
        ContactFormNotifier.with(submission: test_submission).deliver_later(User.where(can_access_settings: true).limit(1))
        flash[:notice] = 'Test SMS notification sent successfully!'
      rescue StandardError => e
        Rails.logger.error "Test SMS error: #{e.message}"
        flash[:alert] = "Failed to send test SMS: #{e.message}"
      ensure
        # Clean up test submission
        test_submission.destroy
      end

      redirect_to edit_lean_cms_notification_settings_path
    end
  end
end
