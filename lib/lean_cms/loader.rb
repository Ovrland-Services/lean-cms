require "yaml"

module LeanCms
  # Loads page content structure from a YAML file into LeanCms::PageContent
  # records. Idempotent — re-running against an unchanged YAML is a no-op;
  # changes to field metadata (label, position, etc.) get applied without
  # clobbering editor-supplied values.
  #
  # Usage from a background job, runner, or one-off script:
  #
  #   result = LeanCms::Loader.new.load!
  #   result.created  # => 28
  #   result.skipped  # => 0
  #
  # Usage from a rake task (with progress on stdout):
  #
  #   LeanCms::Loader.new(logger: Logger.new($stdout)).load!
  #
  # See `lib/tasks/lean_cms.rake` for the thin Rake wrappers.
  class Loader
    Result = Struct.new(:total_fields, :created, :updated, :skipped, keyword_init: true)

    DEFAULT_YAML_PATH = "config/lean_cms_structure.yml".freeze

    class StructureFileMissing < StandardError; end
    class NoUsersFound        < StandardError; end

    def initialize(yaml_path: nil, system_user: nil, logger: nil)
      @yaml_path   = yaml_path || Rails.root.join(DEFAULT_YAML_PATH)
      @system_user = system_user
      @logger      = logger || ActiveSupport::Logger.new(IO::NULL)
    end

    def load!
      raise StructureFileMissing, "Structure file not found at #{@yaml_path}" unless File.exist?(@yaml_path)

      structure = YAML.load_file(@yaml_path)
      pages     = structure["pages"] || {}
      return empty_result if pages.empty?

      user = resolve_system_user
      raise NoUsersFound, "No users in database. Create at least one before loading structure." unless user

      @system_user = user
      @logger.info "Loading LeanCMS page content structure..."
      @logger.info "Using system user: #{user.email_address}"
      @logger.info "=" * 60

      @total = @created = @updated = @skipped = 0

      pages.each do |page_key, page_data|
        load_page(page_key, page_data)
      end

      @logger.info ""
      @logger.info "=" * 60
      @logger.info "Summary:"
      @logger.info "  Total fields: #{@total}"
      @logger.info "  Created: #{@created}"
      @logger.info "  Updated: #{@updated}"
      @logger.info "  Skipped: #{@skipped}"
      @logger.info "=" * 60

      Result.new(total_fields: @total, created: @created, updated: @updated, skipped: @skipped)
    end

    private

    def empty_result
      @logger.warn "No pages defined in structure file at #{@yaml_path}"
      Result.new(total_fields: 0, created: 0, updated: 0, skipped: 0)
    end

    def resolve_system_user
      return @system_user if @system_user

      user_class = LeanCms.user_class.constantize
      user_class.where(is_super_admin: true).first || user_class.first
    end

    def load_page(page_key, page_data)
      sections           = page_data["sections"] || {}
      page_display_title = page_data["display_title"] || page_key.titleize
      page_order         = page_data["page_order"] || 0

      @logger.info ""
      @logger.info "Page: #{page_key.upcase} (#{page_display_title}) [order: #{page_order}]"

      sections.each do |section_key, section_data|
        load_section(page_key, page_display_title, page_order, section_key, section_data)
      end
    end

    def load_section(page_key, page_display_title, page_order, section_key, section_data)
      section_display_title = section_data["display_title"] || section_key.titleize
      section_order         = section_data["section_order"] || 0

      @logger.info "  Section: #{section_key} (#{section_display_title}) [order: #{section_order}]"

      section_meta = {
        page_key:              page_key,
        page_display_title:    page_display_title,
        page_order:            page_order,
        section_key:           section_key,
        section_display_title: section_display_title,
        section_order:         section_order
      }

      (section_data["fields"] || {}).each do |field_key, field_data|
        next unless field_data.is_a?(Hash) && field_data["type"]
        load_field(section_meta, field_key, field_data)
      end

      cards_data = section_data["cards"]
      load_cards(section_meta, cards_data) if cards_data && cards_data["items"]

      bullets_data = section_data["bullets"]
      load_bullets(section_meta, bullets_data) if bullets_data && bullets_data["items"]
    end

    def load_field(meta, field_key, field_data)
      @total += 1
      record = LeanCms::PageContent.find_or_initialize_content(
        page: meta[:page_key], section: meta[:section_key], key: field_key
      )

      apply_common_attributes(record, field_data["label"], field_data["type"], meta)
      apply_default_value(record, field_data["default"]) if record.new_record?
      apply_field_options(record, field_data)
      record.position       = field_data["position"] || 0
      record.last_edited_by = @system_user

      persist(record, label: field_key, type_summary: field_data["type"])
    end

    def load_cards(meta, cards_data)
      @total += 1
      record = LeanCms::PageContent.find_or_initialize_content(
        page: meta[:page_key], section: meta[:section_key], key: "cards"
      )

      apply_common_attributes(record, "Cards", "cards", meta)
      record.position = 999
      record.options  = { "max_cards" => cards_data["max_cards"], "type" => cards_data["type"] }.compact
      record.content  = cards_data["items"].to_json if record.new_record?
      record.last_edited_by = @system_user

      persist(record, label: "cards", type_summary: "#{cards_data['items'].size} items")
    end

    def load_bullets(meta, bullets_data)
      @total += 1
      record = LeanCms::PageContent.find_or_initialize_content(
        page: meta[:page_key], section: meta[:section_key], key: "bullets"
      )

      apply_common_attributes(record, "Bullet Points", "bullets", meta)
      record.position = 999
      record.options  = { "max_items" => bullets_data["max_items"] || 10, "type" => "bullets" }
      record.content  = bullets_data["items"].to_json if record.new_record?
      record.last_edited_by = @system_user

      persist(record, label: "bullets", type_summary: "#{bullets_data['items'].size} items")
    end

    def apply_common_attributes(record, label, content_type, meta)
      record.label              = label
      record.content_type       = content_type
      record.display_title      = meta[:section_display_title]
      record.page_display_title = meta[:page_display_title]
      record.page_order         = meta[:page_order]
      record.section_order      = meta[:section_order]
    end

    def apply_default_value(record, default_value)
      if record.rich_text?
        record.rich_content = default_value
      elsif record.boolean?
        record.value = (default_value == true || default_value == "true").to_s
      elsif default_value
        record.value = default_value.to_s
      end
    end

    def apply_field_options(record, field_data)
      if record.dropdown? && field_data["options"]
        record.options = { "options" => field_data["options"] }
      end

      if field_data["max_length"]
        record.options ||= {}
        record.options = record.options.merge("max_length" => field_data["max_length"].to_i)
      end
    end

    def persist(record, label:, type_summary:)
      if record.new_record?
        if record.save
          @created += 1
          @logger.info "    ✓ Created: #{label} (#{type_summary})"
        else
          @logger.error "    ✗ Error: #{label} - #{record.errors.full_messages.join(', ')}"
        end
      elsif record.changed?
        if record.save
          @updated += 1
          @logger.info "    ↻ Updated: #{label} (#{type_summary})"
        else
          @logger.error "    ✗ Error: #{label} - #{record.errors.full_messages.join(', ')}"
        end
      else
        @skipped += 1
        @logger.info "    - Skipped: #{label} (already exists)"
      end
    end
  end
end
