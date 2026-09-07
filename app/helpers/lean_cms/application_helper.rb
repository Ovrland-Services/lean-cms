module LeanCms
  module ApplicationHelper
    # Darken a hex color by a percentage
    def darken_color(hex_color, percent)
      hex_color = hex_color.gsub('#', '')
      rgb = hex_color.scan(/../).map { |color| color.to_i(16) }
      rgb = rgb.map { |channel| [(channel * (100 - percent) / 100).round, 0].max }
      "##{rgb.map { |channel| channel.to_s(16).rjust(2, '0') }.join}"
    end

    # Format date for display, following the host app's I18n.locale.
    # The gem ships the :lean_cms_date format (date.formats.lean_cms_date) for
    # :en and :"pt-BR"; hosts can override it per-locale in their own locale
    # files. Falls back to Date#to_s rather than raising when the active
    # locale doesn't define the format.
    def format_date(date)
      return unless date
      return date.to_s unless I18n.exists?("date.formats.lean_cms_date")
      I18n.l(date, format: :lean_cms_date)
    end

    # Format datetime for display, following the host app's I18n.locale.
    # See format_date for the format key and fallback behavior.
    def format_datetime(datetime)
      return unless datetime
      return datetime.to_s unless I18n.exists?("time.formats.lean_cms_datetime")
      I18n.l(datetime, format: :lean_cms_datetime)
    end

    # Status badge colors
    def status_badge_class(status)
      case status.to_s
      when 'published'
        'bg-green-100 text-green-800'
      when 'draft'
        'bg-yellow-100 text-yellow-800'
      when 'new_submission'
        'bg-blue-100 text-blue-800'
      when 'read'
        'bg-gray-100 text-gray-800'
      when 'replied'
        'bg-green-100 text-green-800'
      when 'archived'
        'bg-gray-100 text-gray-600'
      else
        'bg-gray-100 text-gray-800'
      end
    end
  end
end
