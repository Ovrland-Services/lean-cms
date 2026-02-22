module LeanCms
  class PageContentsController < LeanCms::ApplicationController
    before_action :require_page_editing
    skip_before_action :check_content_lock
    before_action :check_content_lock, only: [:update]

    def index
      # Get all pages that have content associated with them
      @pages = LeanCms::Page
                .joins(:page_contents)
                .select('lean_cms_pages.*, MIN(lean_cms_page_contents.page_order) as min_page_order')
                .group('lean_cms_pages.id')
                .order('min_page_order, lean_cms_pages.position, lean_cms_pages.title')
                .distinct
                .map { |page| { key: page.slug, display_title: page.title, page: page } }

      @page_structure = {}
      @pages.each do |page_data|
        page_slug = page_data[:key]
        page = page_data[:page]

        sections = LeanCms::PageContent
                    .where(page_id: page.id)
                    .select(:section, :section_order, :display_title)
                    .distinct
                    .order(:section_order)
                    .pluck(:section, :display_title)
                    .uniq

        @page_structure[page_slug] = sections.map do |section, display_title|
          {
            section: section,
            display_title: display_title || section.humanize,
            field_count: LeanCms::PageContent.where(page_id: page.id, section: section).count,
            last_updated: LeanCms::PageContent.where(page_id: page.id, section: section).maximum(:updated_at),
            has_cards: LeanCms::PageContent.where(page_id: page.id, section: section, key: 'cards').exists?,
            has_bullets: LeanCms::PageContent.where(page_id: page.id, section: section, key: 'bullets').exists?
          }
        end
      end
    end

    def edit
      @page = params[:page]
      @section = params[:section]

      # Find the LeanCms::Page by slug
      page_record = LeanCms::Page.find_by(slug: @page)
      
      @fields = if page_record
        # Use page_id for new data structure
        LeanCms::PageContent.where(page_id: page_record.id, section: @section).ordered
      else
        # Fallback to string-based lookup for legacy data
        LeanCms::PageContent.where("page = ? AND section = ?", @page, @section).ordered
      end

      redirect_to lean_cms_page_contents_path, alert: 'Section not found' if @fields.empty?
    end

    def update
      @page = params[:page]
      @section = params[:section]

      success = true
      errors = []

      # Find the LeanCms::Page by slug
      page_record = LeanCms::Page.find_by(slug: @page)

      # Handle business hours special case (hours_json field)
      if params[:hours_labels].present? || params[:hours_note].present?
        hours_json_field = if page_record
          LeanCms::PageContent.find_by(page_id: page_record.id, section: @section, key: 'hours_json')
        else
          LeanCms::PageContent.find_by("page = ? AND section = ? AND key = ?", @page, @section, 'hours_json')
        end
        if hours_json_field
          hours_data = {
            'hours' => build_hours_array,
            'note' => params[:hours_note].to_s
          }
          hours_json_field.value = hours_data.to_json
          hours_json_field.last_edited_by = current_user
          unless hours_json_field.save
            success = false
            errors << "Hours: #{hours_json_field.errors.full_messages.join(', ')}"
          end
        end
      end

      # Handle bullets special case
      if params[:bullet_items].present? && params[:bullets_field_id].present?
        bullets_field = LeanCms::PageContent.find_by(id: params[:bullets_field_id])
        if bullets_field
          bullets_array = params[:bullet_items].map(&:to_s).reject(&:blank?)
          bullets_field.value = bullets_array.to_json
          bullets_field.last_edited_by = current_user
          unless bullets_field.save
            success = false
            errors << "Bullets: #{bullets_field.errors.full_messages.join(', ')}"
          end
        end
      end

      # Update each field in the section
      content_params = params[:page_contents] || {}

      content_params.each do |field_id, field_data|
        content = LeanCms::PageContent.find(field_id)
        content.last_edited_by = current_user

        # Handle different content types
        if content.rich_text?
          content.rich_content = field_data[:value]
        elsif content.image? && field_data[:image_file].present?
          content.image_file.attach(field_data[:image_file])
        elsif content.boolean?
          content.value = (field_data[:value] == '1' || field_data[:value] == 'true').to_s
        elsif content.cards?
          # For cards, the value is already JSON from the hidden input
          cards_json = JSON.parse(field_data[:value]) rescue []

          # Don't overwrite existing cards with an empty array — the cards editor
          # hidden input may be blank when editing other fields in the same section form.
          if cards_json.empty? && content.value.present?
            existing = JSON.parse(content.value) rescue []
            next if existing.any?
          end
          
          # Handle image uploads for cards
          if field_data[:card_images].present?
            # card_images is a hash with index keys: {"0" => file, "1" => file}
            field_data[:card_images].each do |index_str, image_file|
              index = index_str.to_i
              next unless image_file.present? && cards_json[index].present?
              
              # Attach the image to card_images collection
              blob = ActiveStorage::Blob.create_and_upload!(
                io: image_file,
                filename: image_file.original_filename,
                content_type: image_file.content_type
              )
              
              # Attach blob to the PageContent's card_images
              content.card_images.attach(blob)
              
              # Store blob ID in card data
              cards_json[index]['image_id'] = blob.id.to_s
              cards_json[index]['use_image'] = true
            end
          end
          
          # Update cards JSON with image IDs
          content.value = cards_json.to_json
        else
          content.value = field_data[:value]
        end

        unless content.save
          success = false
          errors << "#{content.label}: #{content.errors.full_messages.join(', ')}"
        end
      end

      if success
        # Clear cache for this page.
        # SolidCache does not support delete_matched, so enumerate keys explicitly.
        page_slug = @page.to_s
        cache_scope = page_record ?
          LeanCms::PageContent.where(page_id: page_record.id) :
          LeanCms::PageContent.where("page = ?", page_slug)

        cache_scope.pluck(:section, :key).each do |sec, k|
          Rails.cache.delete("page_content/#{page_slug}/#{sec}/#{k}")
        end
        cache_scope.distinct.pluck(:section).each do |sec|
          Rails.cache.delete("page_section/#{page_slug}/#{sec}")
        end
        Rails.cache.delete("page_structure/#{page_slug}")
        Rails.cache.delete("page_cards/#{page_slug}/#{@section}")
        Rails.cache.delete("page_bullets/#{page_slug}/#{@section}")
        
        # Touch the LeanCms::Page to bust fragment cache
        page_record&.touch

        redirect_to lean_cms_page_contents_path, notice: 'Content updated successfully.'
      else
        redirect_to edit_lean_cms_page_content_path(page: @page, section: @section),
                    alert: "Errors: #{errors.join('; ')}"
      end
    end

    def update_field
      @field = LeanCms::PageContent.find(params[:id])
      @field.last_edited_by = current_user

      # Log what we're updating
      Rails.logger.info "Updating field ##{@field.id}: #{@field.page}/#{@field.section}/#{@field.key}"
      Rails.logger.info "Old value: #{@field.value.inspect}"
      Rails.logger.info "New value: #{params[:value].inspect}"
      Rails.logger.info "Content type: #{@field.content_type}"

      case @field.content_type.to_sym
      when :text, :url, :color, :dropdown
        @field.value = params[:value]
      when :rich_text
        @field.rich_content = params[:value]
      when :boolean
        @field.value = (params[:value] == '1' || params[:value] == 'true').to_s
      when :cards
        # Cards are sent as JSON string
        cards_json = JSON.parse(params[:value]) rescue []
        
        # Handle image uploads for cards
        if params[:card_images].present?
          # card_images is a hash with index keys: {"0" => file, "1" => file}
          params[:card_images].each do |index_str, image_file|
            index = index_str.to_i
            next unless image_file.present? && cards_json[index].present?
            
            # Attach the image to card_images collection
            blob = ActiveStorage::Blob.create_and_upload!(
              io: image_file,
              filename: image_file.original_filename,
              content_type: image_file.content_type
            )
            
            # Attach blob to the PageContent's card_images
            @field.card_images.attach(blob)
            
            # Store blob ID in card data
            cards_json[index]['image_id'] = blob.id.to_s
            cards_json[index]['use_image'] = true
          end
        end
        
        @field.value = cards_json.to_json
      when :bullets
        # Bullets can come as JSON string or array
        if params[:value].is_a?(Array)
          @field.value = params[:value].to_json
        else
          @field.value = params[:value]
        end
      when :image
        if params[:image_file].present?
          @field.image_file.attach(params[:image_file])
        end
      end

      if @field.save
        Rails.logger.info "Field saved successfully. New display value: #{@field.reload.display_value.inspect}"
        
        # Clear cache
        clear_page_cache(@field)

        render json: {
          success: true,
          value: @field.display_value,
          message: 'Content updated successfully'
        }
      else
        Rails.logger.error "Failed to save field: #{@field.errors.full_messages.join(', ')}"
        render json: {
          success: false,
          errors: @field.errors.full_messages
        }, status: :unprocessable_entity
      end
    end

    def edit_field
      @field = LeanCms::PageContent.find(params[:id])

      render partial: 'lean_cms/page_contents/field_editor',
             locals: { field: @field },
             layout: false
    end

    def preview_undo_field
      @field = LeanCms::PageContent.find(params[:id])

      previous_version = @field.versions.where(event: 'update').last

      if previous_version && previous_version.object
        previous_state = YAML.safe_load(
          previous_version.object,
          permitted_classes: [Symbol, Time, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone, Date, DateTime],
          aliases: true
        )

        old_value = previous_state['value']

        if old_value
          render json: {
            success: true,
            current_value: @field.display_value.to_s,
            previous_value: old_value.to_s
          }
        else
          render json: { success: false, error: 'Could not extract previous value' }, status: :unprocessable_entity
        end
      else
        render json: { success: false, error: 'No previous version found' }, status: :not_found
      end
    end

    def undo_field
      @field = LeanCms::PageContent.find(params[:id])
      
      # Get the most recent version from PaperTrail
      previous_version = @field.versions.where(event: 'update').last
      
      if previous_version && previous_version.object
        # Parse the object to get the previous state
        # The 'object' column contains the state BEFORE the change
        previous_state = YAML.safe_load(
          previous_version.object, 
          permitted_classes: [Symbol, Time, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone, Date, DateTime],
          aliases: true
        )
        
        Rails.logger.info "Previous state: #{previous_state.inspect}"
        
        # Extract the old value
        old_value = previous_state['value']
        
        if old_value
          # Set the old value back
          case @field.content_type.to_sym
          when :rich_text
            @field.rich_content = old_value
          else
            @field.value = old_value
          end
          
          @field.last_edited_by = current_user
          
          if @field.save
            Rails.logger.info "Field reverted to previous version. New value: #{@field.reload.display_value.inspect}"
            
            # Clear cache
            clear_page_cache(@field)
            
            render json: {
              success: true,
              value: @field.display_value,
              message: 'Reverted to previous version'
            }
          else
            render json: {
              success: false,
              error: 'Failed to save reverted version'
            }, status: :unprocessable_entity
          end
        else
          render json: {
            success: false,
            error: 'Could not extract previous value'
          }, status: :unprocessable_entity
        end
      else
        render json: {
          success: false,
          error: 'No previous version found'
        }, status: :not_found
        end
    end

    private

    def clear_page_cache(field)
      # SolidCache does not support delete_matched, so enumerate keys explicitly.
      page_obj  = field.page  # LeanCms::Page via belongs_to, or nil for legacy records
      page_slug = page_obj&.slug || field.read_attribute(:page).to_s

      cache_scope = page_obj ?
        LeanCms::PageContent.where(page_id: page_obj.id) :
        LeanCms::PageContent.where("page = ?", page_slug)

      cache_scope.pluck(:section, :key).each do |sec, k|
        Rails.cache.delete("page_content/#{page_slug}/#{sec}/#{k}")
      end
      cache_scope.distinct.pluck(:section).each do |sec|
        Rails.cache.delete("page_section/#{page_slug}/#{sec}")
      end
      Rails.cache.delete("page_structure/#{page_slug}")
      Rails.cache.delete("page_cards/#{page_slug}/#{field.section}")
      Rails.cache.delete("page_bullets/#{page_slug}/#{field.section}")

      # Touch the LeanCms::Page to bust fragment cache
      (page_obj || LeanCms::Page.find_by(slug: page_slug))&.touch
    end

    def build_hours_array
      return [] unless params[:hours_labels]
      params[:hours_labels]
        .zip(params[:hours_values] || [])
        .map { |label, value| { 'label' => label.to_s, 'value' => value.to_s } }
        .reject { |h| h['label'].blank? && h['value'].blank? }
    end
  end
end
