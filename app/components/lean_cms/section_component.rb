module LeanCms
  class SectionComponent < BaseComponent
    attr_reader :section, :title

    def initialize(section:, title: nil, page: nil, **options)
      super(page: page)
      @section = section
      @title = title
      @options = options
    end

    private

    def cache_key
      super(section)
    end

    def display_title
      return title if title.present?
      section.humanize
    end

    def page_title
      page.is_a?(LeanCms::Page) ? page.title : page_slug.titleize
    end

    def full_title
      "#{page_title} - #{display_title}"
    end

    def edit_url
      @view_context.lean_cms_edit_page_content_path(page: page_slug, section: section)
    end
  end
end
