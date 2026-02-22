module LeanCms
  class MetaTag < ApplicationRecord
    self.table_name = 'lean_cms_meta_tags'

    belongs_to :taggable, polymorphic: true

    validates :title, length: { maximum: 60 }, allow_blank: true
    validates :description, length: { maximum: 160 }, allow_blank: true

    # Get title with fallback
    def title_with_fallback(fallback = nil)
      title.presence || fallback
    end

    # Get description with fallback
    def description_with_fallback(fallback = nil)
      description.presence || fallback
    end

    # Check if has open graph image
    def has_og_image?
      og_image_url.present?
    end

    # Check if has structured data
    def has_structured_data?
      structured_data.present? && structured_data.is_a?(Hash)
    end
  end
end
