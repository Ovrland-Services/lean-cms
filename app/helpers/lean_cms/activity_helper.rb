module LeanCms
  module ActivityHelper
    def activity_item_label(version)
      case version.item_type
      when "LeanCms::Setting"
        setting = parsed_setting_object(version)
        "Setting: #{setting&.dig('key') || version.item_id}"
      when "LeanCms::PageContent"
        pc = version.item_type.constantize.unscoped.find_by(id: version.item_id)
        if pc
          page_slug = pc.page&.full_path || pc.page&.slug || pc.read_attribute(:page).to_s
          "Page Content: #{page_slug}/#{pc.section}/#{pc.key}"
        else
          "Page Content ##{version.item_id}"
        end
      when "LeanCms::Post"
        post = version.item_type.constantize.unscoped.find_by(id: version.item_id)
        post ? "Post: #{post.title}" : "Post ##{version.item_id}"
      when "User"
        user = User.unscoped.find_by(id: version.item_id)
        user ? "User: #{user.email_address}" : "User ##{version.item_id}"
      when "LeanCms::FormSubmission"
        fs = version.item_type.constantize.unscoped.find_by(id: version.item_id)
        fs ? "Form Submission ##{version.item_id}" : "Form Submission ##{version.item_id}"
      else
        "#{version.item_type} ##{version.item_id}"
      end
    rescue
      "#{version.item_type} ##{version.item_id}"
    end

    def activity_who(version)
      return "System" if version.whodunnit.blank?
      user = User.unscoped.find_by(id: version.whodunnit)
      user ? user.email_address : "User ##{version.whodunnit}"
    rescue
      "User ##{version.whodunnit}"
    end

    def activity_action_badge_class(event)
      case event.to_s
      when "create" then "bg-green-100 text-green-800"
      when "update" then "bg-blue-100 text-blue-800"
      when "destroy" then "bg-red-100 text-red-800"
      else "bg-gray-100 text-gray-800"
      end
    end

    def activity_old_value(version)
      return "—" if version.event == "create"
      obj = parsed_version_object(version)
      return "—" if obj.blank?

      format_attributes_for_display(obj, version.item_type)
    rescue
      "—"
    end

    def activity_new_value(version)
      return "—" if version.event == "destroy"
      obj = parsed_version_object(version)
      return "—" if obj.blank? && version.event != "create"

      case version.item_type
      when "LeanCms::Setting"
        if version.event == "create"
          obj["value"].to_s.truncate(80)
        else
          item = version.item_type.constantize.unscoped.find_by(id: version.item_id)
          item&.value&.to_s&.truncate(80) || "—"
        end
      else
        if version.event == "create"
          format_attributes_for_display(obj, version.item_type)
        else
          item = version.item_type.constantize.unscoped.find_by(id: version.item_id)
          item ? truncate_item_summary(item) : "—"
        end
      end
    rescue
      "—"
    end

    private

    def parsed_version_object(version)
      return {} if version.object.blank?
      YAML.safe_load(
        version.object,
        permitted_classes: [Symbol, Time, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone, Date, DateTime],
        aliases: true
      ) || {}
    rescue
      {}
    end

    def parsed_setting_object(version)
      parsed_version_object(version)
    end

    def truncate_item_summary(item)
      case item.class.name
      when "LeanCms::PageContent"
        page_slug = item.page&.full_path || item.page&.slug || item.read_attribute(:page).to_s
        value_summary = format_display_value(item.display_value)
        "#{page_slug}/#{item.section}/#{item.key}: #{value_summary}"
      when "LeanCms::Post"
        item.title.to_s.truncate(60)
      when "LeanCms::Page"
        "#{item.title} (#{item.slug})"
      when "User"
        item.email_address.to_s
      when "LeanCms::FormSubmission"
        "Submission ##{item.id}"
      else
        item.to_s.truncate(60)
      end
    rescue
      "—"
    end

    def format_attributes_for_display(obj, item_type)
      case item_type
      when "LeanCms::Setting"
        obj["value"].to_s.truncate(80)
      when "LeanCms::PageContent"
        page_slug = safe_page_slug(obj["page"])
        section = obj["section"].to_s.presence || "—"
        key = obj["key"].to_s.presence || "—"
        value_summary = format_value_from_attributes(obj)
        "#{page_slug}/#{section}/#{key}: #{value_summary}"
      when "LeanCms::Post"
        parts = []
        parts << obj["title"].to_s if obj["title"].present?
        parts << obj["excerpt"].to_s.truncate(40) if obj["excerpt"].present?
        parts.any? ? parts.join(" — ").truncate(80) : "Post ##{obj["id"]}"
      when "LeanCms::Page"
        title = obj["title"].to_s.presence || "—"
        slug = obj["slug"].to_s.presence || "—"
        "#{title} (#{slug})"
      when "User"
        obj["email_address"].to_s.presence || obj["name"].to_s.presence || "User ##{obj["id"]}"
      when "LeanCms::FormSubmission"
        "Submission ##{obj["id"]}"
      else
        safe_attributes_summary(obj)
      end
    rescue
      "—"
    end

    def safe_page_slug(page_attr)
      return "—" if page_attr.blank?
      return page_attr.to_s if page_attr.is_a?(String)
      page_attr.respond_to?(:slug) ? page_attr.slug.to_s : page_attr.respond_to?(:full_path) ? page_attr.full_path.to_s : "—"
    end

    def format_value_from_attributes(obj)
      val = obj["value"].to_s.presence || obj["content"].to_s.presence
      return "—" if val.blank?
      stripped = val.gsub(/<[^>]*>/, " ").squish
      stripped.present? ? stripped.truncate(50) : "—"
    end

    def format_display_value(val)
      return "—" if val.blank?
      return val.truncate(40) if val.is_a?(String)
      return "Cards (#{val.size})" if val.is_a?(Array)
      return "Image attached" if val.respond_to?(:attached?) && val.attached?
      return "Image attached" if val.is_a?(ActiveStorage::Attached::One)
      val.to_s.truncate(40)
    end

    def safe_attributes_summary(obj)
      skip = %w[created_at updated_at id]
      filtered = obj.except(*skip).transform_values { |v| safe_attribute_value(v) }
      filtered.reject! { |_, v| v.blank? }
      filtered.any? ? filtered.map { |k, v| "#{k}: #{v}" }.join("; ").truncate(80) : "—"
    end

    def safe_attribute_value(v)
      return v.to_s if v.is_a?(String) || v.is_a?(Numeric) || v == true || v == false
      return v.strftime("%Y-%m-%d %H:%M") if v.respond_to?(:strftime)
      return v.slug.to_s if v.respond_to?(:slug)
      return v.title.to_s if v.respond_to?(:title)
      return v.email_address.to_s if v.respond_to?(:email_address)
      "—"
    end
  end
end
