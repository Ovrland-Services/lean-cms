module LeanCms
  class NotificationSetting < ApplicationRecord
    self.table_name = 'lean_cms_notification_settings'

    # Encrypt sensitive credentials using Rails built-in encryption
    encrypts :sendgrid_api_key
    encrypts :mailgun_api_key
    encrypts :twilio_account_sid
    encrypts :twilio_auth_token

    # Singleton pattern - only one settings record
    def self.instance
      first_or_create! do |setting|
        setting.email_provider = 'none'
        setting.email_enabled = false
        setting.sms_enabled = false
        setting.in_app_enabled = true
        setting.notification_emails = '[]'
        setting.notification_phones = '[]'
      end
    end

    def notification_email_list
      JSON.parse(notification_emails || '[]')
    end

    def notification_email_list=(emails)
      self.notification_emails = emails.is_a?(Array) ? emails.to_json : emails
    end

    def notification_phone_list
      JSON.parse(notification_phones || '[]')
    end

    def notification_phone_list=(phones)
      self.notification_phones = phones.is_a?(Array) ? phones.to_json : phones
    end

    # Validation
    validates :email_provider, inclusion: { in: %w[sendgrid mailgun none] }, allow_nil: true
    validate :email_provider_required_if_enabled
    validate :credentials_required_if_enabled

    private

    def email_provider_required_if_enabled
      if email_enabled? && email_provider == 'none'
        errors.add(:email_provider, 'must be selected when email notifications are enabled')
      end
    end

    def credentials_required_if_enabled
      if email_enabled? && email_provider == 'sendgrid' && sendgrid_api_key.blank?
        errors.add(:sendgrid_api_key, 'is required when Sendgrid is enabled')
      end

      if email_enabled? && email_provider == 'mailgun'
        errors.add(:mailgun_api_key, 'is required when Mailgun is enabled') if mailgun_api_key.blank?
        errors.add(:mailgun_domain, 'is required when Mailgun is enabled') if mailgun_domain.blank?
      end

      if sms_enabled?
        errors.add(:twilio_account_sid, 'is required when SMS is enabled') if twilio_account_sid.blank?
        errors.add(:twilio_auth_token, 'is required when SMS is enabled') if twilio_auth_token.blank?
        errors.add(:twilio_from_number, 'is required when SMS is enabled') if twilio_from_number.blank?
      end
    end
  end
end
