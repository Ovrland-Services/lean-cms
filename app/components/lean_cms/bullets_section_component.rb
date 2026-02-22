module LeanCms
  class BulletsSectionComponent < BaseComponent
    attr_reader :section

    def initialize(section:, page: nil, **options)
      super(page: page)
      @section = section
      @options = options
    end

    private

    def cache_key
      super("#{section}_bullets")
    end

    def bullets
      if page.is_a?(LeanCms::Page) && page.page_contents.loaded?
        content_record = page.page_contents.find { |pc| pc.section == section.to_s && pc.key == 'bullets' }
        return [] unless content_record&.bullets?
        content_record.display_value
      else
        page_key = page.is_a?(LeanCms::Page) ? page.slug : page.to_s
        Rails.cache.fetch("page_bullets/#{page_key}/#{section}", expires_in: 1.hour) do
          content_record = if page.is_a?(LeanCms::Page)
            LeanCms::PageContent.find_by(page_id: page.id, section: section, key: 'bullets')
          else
            LeanCms::PageContent.find_by("page = ? AND section = ? AND key = ?", page.to_s, section.to_s, 'bullets')
          end
          return [] unless content_record&.bullets?
          content_record.display_value
        end
      end
    end

    def field
      @field ||= find_field(section, 'bullets')
    end

    def data_attributes
      return {} unless can_edit_cms? && field

      {
        controller: 'inline-edit',
        inline_edit_field_id_value: field.id,
        inline_edit_type_value: 'bullets',
        inline_edit_inline_value: false,
        inline_edit_page_value: page_slug,
        inline_edit_section_value: section,
        inline_edit_key_value: 'bullets'
      }
    end
  end
end
