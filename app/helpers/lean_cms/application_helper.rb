module LeanCms
  module ApplicationHelper
    # Darken a hex color by a percentage
    def darken_color(hex_color, percent)
      hex_color = hex_color.gsub('#', '')
      rgb = hex_color.scan(/../).map { |color| color.to_i(16) }
      rgb = rgb.map { |channel| [(channel * (100 - percent) / 100).round, 0].max }
      "##{rgb.map { |channel| channel.to_s(16).rjust(2, '0') }.join}"
    end

    # Format date for display
    def format_date(date)
      return unless date
      date.strftime("%B %d, %Y")
    end

    # Format datetime for display
    def format_datetime(datetime)
      return unless datetime
      datetime.strftime("%B %d, %Y at %I:%M %p")
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
