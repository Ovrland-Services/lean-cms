module LeanCms
  class SettingsController < ApplicationController
    skip_before_action :check_content_lock
    before_action :require_settings_access

    def edit
      # Load current settings (default to enabled for backward compatibility)
      @in_context_editing_enabled = LeanCms::Setting.get('in_context_editing', 'true') == 'true'
      @show_blog_enabled = LeanCms::Setting.get('show_blog', 'true') == 'true'
      @show_portfolio_enabled = LeanCms::Setting.get('show_portfolio', 'true') == 'true'
      
      # Load counts for display
      @blog_count = LeanCms::Post.published.blog_posts.count
      @portfolio_count = LeanCms::Post.published.portfolio_items.count

      # Blog and Portfolio hero text
      @blog_title = LeanCms::Setting.get('blog_title', 'Our Blog')
      @blog_subtitle = LeanCms::Setting.get('blog_subtitle', 'Insights, updates, and stories from Custom Assembly Services')
      @portfolio_title = LeanCms::Setting.get('portfolio_title', 'Our Portfolio')
      @portfolio_subtitle = LeanCms::Setting.get('portfolio_subtitle', 'Showcasing our industrial assembly and installation projects')

      # Privacy & Compliance
      @cookie_consent_enabled = LeanCms::Setting.get('cookie_consent_enabled', 'false') == 'true'
      @cookie_consent_message = LeanCms::Setting.get('cookie_consent_message', 'We use cookies to improve your experience and analyze site traffic. You can choose which cookies to allow.')
      @cookie_consent_forced_on = LeanCms::Setting.enabled?('google_analytics_enabled')

      # Analytics
      @google_analytics_enabled = LeanCms::Setting.enabled?('google_analytics_enabled')
      @google_analytics_id = LeanCms::Setting.get('google_analytics_id', '')
    end

    def update
      # Update in-context editing setting
      LeanCms::Setting.set('in_context_editing', params[:in_context_editing] == '1' ? 'true' : 'false')
      
      # Update show blog and portfolio settings
      LeanCms::Setting.set('show_blog', params[:show_blog] == '1' ? 'true' : 'false')
      LeanCms::Setting.set('show_portfolio', params[:show_portfolio] == '1' ? 'true' : 'false')

      # Update blog and portfolio hero text
      LeanCms::Setting.set('blog_title', params[:blog_title].to_s) if params.key?(:blog_title)
      LeanCms::Setting.set('blog_subtitle', params[:blog_subtitle].to_s) if params.key?(:blog_subtitle)
      LeanCms::Setting.set('portfolio_title', params[:portfolio_title].to_s) if params.key?(:portfolio_title)
      LeanCms::Setting.set('portfolio_subtitle', params[:portfolio_subtitle].to_s) if params.key?(:portfolio_subtitle)

      # Update site address (as structured JSON)
      address_data = {
        'street1' => params[:site_street1].to_s,
        'street2' => params[:site_street2].to_s,
        'city' => params[:site_city].to_s,
        'state' => params[:site_state].to_s.upcase,
        'zip' => params[:site_zip].to_s
      }
      LeanCms::Setting.set_json('site_address', address_data)

      # Update phone and email
      LeanCms::Setting.set('site_phone', params[:site_phone]) if params[:site_phone]
      LeanCms::Setting.set('site_email', params[:site_email]) if params[:site_email]

      # Update business hours (as JSON)
      if params[:business_hours_labels] || params[:business_hours_note]
        hours_data = {
          'hours' => build_hours_array,
          'note' => params[:business_hours_note].to_s
        }
        LeanCms::Setting.set_json('business_hours', hours_data)
      end

      # Update Google Analytics (when enabled, force cookie consent on)
      LeanCms::Setting.set('google_analytics_enabled', params[:google_analytics_enabled] == '1' ? 'true' : 'false')
      LeanCms::Setting.set('google_analytics_id', params[:google_analytics_id].to_s.strip) if params.key?(:google_analytics_id)
      LeanCms::Setting.set('cookie_consent_enabled', 'true') if LeanCms::Setting.enabled?('google_analytics_enabled')

      # Update cookie consent (cannot disable if GA is enabled)
      if params.key?(:cookie_consent_enabled)
        forced_on = LeanCms::Setting.enabled?('google_analytics_enabled')
        value = params[:cookie_consent_enabled] == '1' ? 'true' : 'false'
        LeanCms::Setting.set('cookie_consent_enabled', forced_on ? 'true' : value)
      end
      LeanCms::Setting.set('cookie_consent_message', params[:cookie_consent_message].to_s) if params.key?(:cookie_consent_message)

      redirect_to lean_cms_settings_path, notice: 'Settings updated successfully.'
    end

    def lock
      reason = params[:reason].presence || 'Content sync in progress'
      LeanCms::Setting.lock_content!(reason)
      redirect_to lean_cms_settings_path, notice: "Content editing locked: #{reason}"
    end

    def unlock
      LeanCms::Setting.unlock_content!
      redirect_to lean_cms_settings_path, notice: 'Content editing unlocked. Editors can now make changes.'
    end

    # AJAX endpoint to toggle override settings
    def update_override
      allowed_keys = %w[contact_info_override contact_hours_override]
      key = params[:key]
      value = params[:value]

      if allowed_keys.include?(key) && %w[true false].include?(value)
        LeanCms::Setting.set(key, value)
        head :ok
      else
        head :unprocessable_entity
      end
    end

    private

    def build_hours_array
      return [] unless params[:business_hours_labels]
      params[:business_hours_labels]
        .zip(params[:business_hours_values] || [])
        .map { |label, value| { 'label' => label.to_s, 'value' => value.to_s } }
        .reject { |h| h['label'].blank? && h['value'].blank? }
    end
  end
end
