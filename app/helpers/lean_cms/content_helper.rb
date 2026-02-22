module LeanCms
  module ContentHelper
    # Render editable content section
    def render_editable_section(page_key, section_key, default: nil, **options)
      content = LeanCms::PageContent.for_section(page_key, section_key)

      if content.persisted?
        case content.content_type.to_sym
        when :rich
          content_tag(:div, content.rich_content, **options)
        when :markdown
          # TODO: Add markdown rendering with a gem like Redcarpet
          content_tag(:div, simple_format(content.content), **options)
        else
          content_tag(:div, content.content, **options)
        end
      else
        default
      end
    end

    # Check if current user can edit CMS content
    def can_edit_cms?
      current_user&.has_any_cms_permission?
    end

    # Show edit link if user is CMS editor
    def cms_edit_link(path, text: "Edit", css_class: "")
      return unless can_edit_cms?

      link_to text, path, class: "cms-edit-link #{css_class}".strip
    end
  end
end
