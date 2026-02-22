module LeanCms
  class BaseComponent < ViewComponent::Base
    attr_reader :page

    def initialize(page: nil, **options)
      @page = page || @view_context.instance_variable_get(:@page)
      super(**options)
    end

    private

    # Check if current user can edit CMS content
    def can_edit_cms?
      return false unless @view_context.respond_to?(:authenticated?) && @view_context.authenticated?
      return false unless @view_context.current_user&.has_any_cms_permission?
      LeanCms::Setting.get('in_context_editing', 'true') == 'true'
    end

    # Generate cache key for this component
    def cache_key(identifier)
      page_slug = page.is_a?(LeanCms::Page) ? page.slug : page.to_s
      # Include page updated_at to bust cache when any PageContent changes (via touch: true)
      ["lean_cms", page_slug, identifier, page&.updated_at&.to_i, can_edit_cms?]
    end

    # Get page slug (string)
    def page_slug
      page.is_a?(LeanCms::Page) ? page.slug : page.to_s
    end

    # Find a PageContent field using preloaded data if available
    def find_field(section, key)
      if page.is_a?(LeanCms::Page) && page.page_contents.loaded?
        page.page_contents.find { |pc| pc.section == section.to_s && pc.key == key.to_s }
      elsif page.is_a?(LeanCms::Page)
        LeanCms::PageContent.find_by(page_id: page.id, section: section, key: key)
      else
        LeanCms::PageContent.find_by("page = ? AND section = ? AND key = ?", page.to_s, section.to_s, key.to_s)
      end
    end

    # Get field value using preloaded data if available
    def field_value(section, key, default: nil)
      field = find_field(section, key)
      field&.display_value || default
    end

    # Expose helpers to components
    def helpers
      @view_context
    end
  end
end
