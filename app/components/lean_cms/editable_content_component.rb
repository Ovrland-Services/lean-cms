module LeanCms
  class EditableContentComponent < BaseComponent
    attr_reader :section, :key, :tag, :default, :html_options

    def initialize(section:, key:, tag: :span, default: nil, page: nil, **html_options)
      super(page: page)
      @section = section
      @key = key
      @tag = tag
      @default = default
      @html_options = html_options
    end

    private

    attr_reader :field

    def field
      @field ||= find_field(section, key)
    end

    def value
      if field&.rich_text?
        helpers.page_content_html(page, section, key, default: default)
      else
        field_value(section, key, default: default)
      end
    end

    def inline_editable?
      field&.text? || field&.url? || field&.color?
    end

    def data_attributes
      return {} unless can_edit_cms? && field

      {
        controller: 'inline-edit',
        inline_edit_field_id_value: field.id,
        inline_edit_type_value: field.content_type,
        inline_edit_inline_value: inline_editable?,
        inline_edit_page_value: page_slug,
        inline_edit_section_value: section,
        inline_edit_key_value: key
      }
    end

    def css_classes
      base_classes = html_options[:class] || ''
      can_edit_cms? && field ? "#{base_classes} cms-inline-field".strip : base_classes
    end
  end
end
