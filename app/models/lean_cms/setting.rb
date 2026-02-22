class LeanCms::Setting < ApplicationRecord
  self.table_name = 'lean_cms_settings'

  has_paper_trail

  validates :key, presence: true, uniqueness: true

  class << self
    def get(key, default = nil)
      Rails.cache.fetch("lean_cms_setting/#{key}", expires_in: 1.hour) do
        setting = find_by(key: key)
        setting&.value || default
      end
    end

    def set(key, value)
      setting = find_or_initialize_by(key: key)
      setting.value = value.to_s
      PaperTrail.request(whodunnit: Current.user&.id&.to_s) do
        setting.save!
      end
      Rails.cache.delete("lean_cms_setting/#{key}")
      value
    end

    # Bypass cache - use for settings that must take effect immediately (e.g. cookie consent)
    def get_uncached(key, default = nil)
      setting = find_by(key: key)
      setting&.value || default
    end

    def enabled?(key)
      get(key, 'false') == 'true'
    end

    # JSON storage helpers
    def get_json(key, default = {})
      raw = get(key)
      return default if raw.blank?
      JSON.parse(raw)
    rescue JSON::ParserError
      default
    end

    def set_json(key, value)
      set(key, value.to_json)
    end

    # Site information convenience methods

    # Returns structured address data as hash
    def site_address_data
      get_json('site_address', {
        'street1' => '',
        'street2' => '',
        'city' => '',
        'state' => '',
        'zip' => ''
      })
    end

    # Returns formatted address string for display
    def site_address
      data = site_address_data
      parts = []
      parts << data['street1'] if data['street1'].present?
      parts << data['street2'] if data['street2'].present?

      city_state_zip = []
      city_state_zip << data['city'] if data['city'].present?
      city_state_zip << data['state'] if data['state'].present?
      city_state_zip << data['zip'] if data['zip'].present?

      parts << city_state_zip.join(', ') if city_state_zip.any?
      parts.join("\n")
    end

    # Returns single-line formatted address
    def site_address_single_line
      data = site_address_data
      parts = []
      parts << data['street1'] if data['street1'].present?
      parts << data['street2'] if data['street2'].present?

      city_state = []
      city_state << data['city'] if data['city'].present?
      city_state << data['state'] if data['state'].present?

      location = city_state.join(', ')
      location += " #{data['zip']}" if data['zip'].present?

      parts << location if location.present?
      parts.join(', ')
    end

    def site_phone
      get('site_phone', '')
    end

    def site_email
      get('site_email', '')
    end

    def business_hours
      get_json('business_hours', { 'hours' => [], 'note' => '' })
    end

    # Content lock methods for sync workflow
    def content_locked?
      enabled?('content_locked')
    end

    def lock_content!(reason = nil)
      set('content_locked', 'true')
      set('content_locked_at', Time.current.iso8601)
      set('content_locked_reason', reason) if reason
    end

    def unlock_content!
      set('content_locked', 'false')
      Rails.cache.delete("lean_cms_setting/content_locked_at")
      Rails.cache.delete("lean_cms_setting/content_locked_reason")
    end

    def content_lock_info
      return nil unless content_locked?
      {
        locked_at: get('content_locked_at'),
        reason: get('content_locked_reason', 'Content sync in progress')
      }
    end
  end
end
