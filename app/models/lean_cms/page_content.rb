module LeanCms
  class PageContent < ApplicationRecord
    self.table_name = 'lean_cms_page_contents'

    has_paper_trail

    belongs_to :page, class_name: 'LeanCms::Page', optional: true, touch: true
    belongs_to :last_edited_by, class_name: 'User', optional: true

    validates :page, :section, :key, presence: true
    validates :key, uniqueness: { scope: [:page, :section] }
    validates :content_type, presence: true
    validate :validate_max_length

    # Content types: text, rich_text, image, boolean, url, color, dropdown, cards, bullets
    enum :content_type, {
      text: 0,
      rich_text: 1,
      image: 2,
      boolean: 3,
      url: 4,
      color: 5,
      dropdown: 6,
      cards: 7,
      bullets: 8
    }

    # Rich text for rich_text content type
    has_rich_text :rich_content

    # Image attachment for image content type
    has_one_attached :image_file

    # Multiple image attachments for cards content type
    has_many_attached :card_images

    # Scopes
    scope :for_page, ->(page) { 
      if page.is_a?(LeanCms::Page)
        where(page_id: page.id)
      else
        where("page = ?", page.to_s)
      end
    }
    scope :for_section, ->(page, section) { 
      if page.is_a?(LeanCms::Page)
        where(page_id: page.id, section: section)
      else
        where("page = ?", page.to_s).where(section: section)
      end
    }
    scope :ordered, -> { order(:position, :key) }

    # Class methods to fetch content
    class << self
      # Get all content for a page grouped by section
      def page_structure(page)
        for_page(page).ordered.group_by(&:section).transform_values do |contents|
          contents.index_by(&:key).transform_values(&:display_value)
        end
      end

      # Get all content for a specific section as a hash
      def section_content(page, section)
        for_section(page, section).ordered.index_by(&:key).transform_values(&:display_value)
      end

      # Get a single field value
      def field_value(page, section, key, default: nil)
        if page.is_a?(LeanCms::Page)
          find_by(page_id: page.id, section: section, key: key)&.display_value || default
        else
          find_by("page = ? AND section = ? AND key = ?", page.to_s, section.to_s, key.to_s)&.display_value || default
        end
      end
    end

    # Get the display value based on content type
    def display_value
      case content_type.to_sym
      when :text
        value.presence || content
      when :rich_text
        rich_content.present? ? rich_content.to_s : value.presence || content
      when :image
        image_file.attached? ? image_file : (value.presence || content)
      when :boolean
        # Store as string "true"/"false", return as boolean
        value == "true" || value == true || value == "1"
      when :url
        value.presence || content
      when :color
        value.presence || content
      when :dropdown
        value.presence || content
      when :cards
        # Cards are stored as JSON in the value field
        parse_cards_json
      when :bullets
        # Bullets are stored as JSON array
        parse_bullets_json
      else
        value.presence || content
      end
    end

    # Parse cards JSON data
    def parse_cards_json
      return [] unless cards?

      cards_data = if value.present?
        JSON.parse(value) rescue []
      elsif content.present?
        JSON.parse(content) rescue []
      else
        []
      end

      # Return cards data as-is, image attachments will be looked up separately when needed
      cards_data.map { |card| card.with_indifferent_access }
    end

    # Get image attachment for a specific card by image_id
    def card_image(image_id)
      return nil unless image_id.present? && card_images.attached?
      card_images.find { |img| img.blob.id.to_s == image_id.to_s }
    end

    # Parse bullets JSON data (similar to cards)
    def parse_bullets_json
      return [] unless bullets?

      if value.present?
        JSON.parse(value) rescue []
      elsif content.present?
        JSON.parse(content) rescue []
      else
        []
      end
    end

    # Set the value based on content type
    def set_value(new_value)
      case content_type.to_sym
      when :boolean
        self.value = new_value.to_s
      when :rich_text
        self.rich_content = new_value
        self.value = new_value.to_s if new_value.present?
      when :cards
        # Store cards as JSON
        self.value = new_value.is_a?(String) ? new_value : new_value.to_json
      else
        self.value = new_value.to_s
      end
    end

    # Get parsed options for dropdown fields
    def parsed_options
      return [] unless dropdown?

      if options.is_a?(Array)
        options
      elsif options.is_a?(Hash)
        options['options'] || []
      else
        []
      end
    end

    # Get max_length from options (for text fields)
    def max_length
      return nil unless options.is_a?(Hash)
      options['max_length']&.to_i
    end

    private

    # Validate value doesn't exceed max_length
    def validate_max_length
      return unless max_length.present? && max_length > 0
      return unless text? || rich_text?

      content_value = value.presence || content
      return if content_value.blank?

      # Strip HTML tags for rich_text to get actual character count
      plain_text = if rich_text?
        ActionController::Base.helpers.strip_tags(content_value.to_s)
      else
        content_value.to_s
      end

      if plain_text.length > max_length
        errors.add(:value, "exceeds maximum length of #{max_length} characters (currently #{plain_text.length})")
      end
    end
  end
end
