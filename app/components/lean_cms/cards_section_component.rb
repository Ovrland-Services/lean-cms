module LeanCms
  class CardsSectionComponent < BaseComponent
    attr_reader :section, :grid_cols, :gap, :container_class, :card_class, :icon_size, 
                :icon_shape, :icon_bg_gradient, :text_align, :ignore_card_bg, 
                :scroll_animate, :stagger_delay

    def initialize(section:, page: nil, grid_cols: 3, gap: 8, container_class: '', 
                   card_class: 'bg-white rounded-xl p-8 shadow-sm hover:shadow-md transition-shadow',
                   icon_size: 12, icon_shape: 'lg', icon_bg_gradient: false,
                   text_align: nil, ignore_card_bg: false, scroll_animate: false,
                   stagger_delay: 150, **options)
      super(page: page)
      @section = section
      @grid_cols = grid_cols
      @gap = gap
      @container_class = container_class
      @card_class = card_class
      @icon_size = icon_size
      @icon_shape = icon_shape
      @icon_bg_gradient = icon_bg_gradient
      @text_align = text_align
      @ignore_card_bg = ignore_card_bg
      @scroll_animate = scroll_animate
      @stagger_delay = stagger_delay
      @options = options
    end

    private

    def cache_key
      super("#{section}_cards")
    end

    def cards
      if page.is_a?(LeanCms::Page) && page.page_contents.loaded?
        content_record = page.page_contents.find { |pc| pc.section == section.to_s && pc.key == 'cards' }
        return [] unless content_record&.cards?
        content_record.display_value
      else
        page_key = page.is_a?(LeanCms::Page) ? page.slug : page.to_s
        Rails.cache.fetch("page_cards/#{page_key}/#{section}", expires_in: 1.hour) do
          content_record = if page.is_a?(LeanCms::Page)
            LeanCms::PageContent.find_by(page_id: page.id, section: section, key: 'cards')
          else
            LeanCms::PageContent.find_by("page = ? AND section = ? AND key = ?", page.to_s, section.to_s, 'cards')
          end
          return [] unless content_record&.cards?
          content_record.display_value
        end
      end
    end

    def field
      @field ||= find_field(section, 'cards')
    end

    def data_attributes
      return {} unless can_edit_cms? && field

      {
        controller: 'inline-edit',
        inline_edit_field_id_value: field.id,
        inline_edit_type_value: 'cards',
        inline_edit_inline_value: false,
        inline_edit_page_value: page_slug,
        inline_edit_section_value: section,
        inline_edit_key_value: 'cards'
      }
    end
  end
end
