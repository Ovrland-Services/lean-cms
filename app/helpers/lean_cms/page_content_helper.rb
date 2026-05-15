module LeanCms
  module PageContentHelper
    # Get a single field value from page content
    # Usage: page_content('home', 'hero', 'heading') or page_content(@page, 'hero', 'heading')
    def page_content(page, section, key, default: nil)
      # Use preloaded content if available (eliminates N+1)
      if page.is_a?(LeanCms::Page) && page.page_contents.loaded?
        field = page.page_contents.find { |pc| pc.section == section.to_s && pc.key == key.to_s }
        return field&.display_value || default
      end
      
      # Fall back to cached query
      page_key = page.is_a?(LeanCms::Page) ? page.slug : page.to_s
      Rails.cache.fetch("page_content/#{page_key}/#{section}/#{key}", expires_in: 1.hour) do
        LeanCms::PageContent.field_value(page, section, key, default: default)
      end
    end

    # Get all content for a section as a hash
    # Usage: page_section('home', 'hero') => { 'heading' => 'Welcome', 'body' => '...' }
    def page_section(page, section)
      page_key = page.is_a?(LeanCms::Page) ? page.slug : page.to_s
      Rails.cache.fetch("page_section/#{page_key}/#{section}", expires_in: 1.hour) do
        LeanCms::PageContent.section_content(page, section)
      end
    end

    # Get all content for a page grouped by section
    # Usage: page_structure('home') => { 'hero' => { 'heading' => '...', 'body' => '...' }, 'features' => {...} }
    def page_structure(page)
      page_key = page.is_a?(LeanCms::Page) ? page.slug : page.to_s
      Rails.cache.fetch("page_structure/#{page_key}", expires_in: 1.hour) do
        LeanCms::PageContent.page_structure(page)
      end
    end

    # Check if a boolean field is true
    # Usage: page_content?('home', 'features', 'show_banner')
    def page_content?(page, section, key, default: false)
      value = page_content(page, section, key, default: default)
      # Handle string booleans
      return true if value == true || value == "true" || value == "1"
      return false if value == false || value == "false" || value == "0"
      !!value
    end

    # Render rich text content safely
    # Usage: page_content_html('home', 'hero', 'body')
    def page_content_html(page, section, key, default: nil)
      content = page_content(page, section, key, default: default)
      return content if content.is_a?(ActionText::RichText)
      return content if content.respond_to?(:to_trix_html)
      sanitize(content.to_s)
    end

    # Get image URL for an image field
    # Usage: page_content_image_url('home', 'hero', 'background')
    def page_content_image_url(page, section, key, variant: nil)
      content_record = if page.is_a?(LeanCms::Page)
        LeanCms::PageContent.find_by(page_id: page.id, section: section, key: key)
      else
        LeanCms::PageContent.find_by("page = ? AND section = ? AND key = ?", page.to_s, section.to_s, key.to_s)
      end
      return nil unless content_record

      if content_record.image_file.attached?
        variant ? content_record.image_file.variant(variant) : content_record.image_file
      else
        content_record.value
      end
    end

    # Get cards for a section
    # Usage: page_cards('about', 'certifications_standards')
    def page_cards(page, section)
      # Use preloaded content if available
      if page.is_a?(LeanCms::Page) && page.page_contents.loaded?
        content_record = page.page_contents.find { |pc| pc.section == section.to_s && pc.key == 'cards' }
        return [] unless content_record&.cards?
        return content_record.display_value
      end
      
      # Fall back to cached query
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

    # Get bullets for a section
    # Usage: page_bullets('contact', 'why_partner')
    def page_bullets(page, section)
      # Use preloaded content if available
      if page.is_a?(LeanCms::Page) && page.page_contents.loaded?
        content_record = page.page_contents.find { |pc| pc.section == section.to_s && pc.key == 'bullets' }
        return [] unless content_record&.bullets?
        return content_record.display_value
      end
      
      # Fall back to cached query
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

    # Render a CMS section with built-in caching and edit controls
    # Usage: <%= cms_section('hero', title: 'Hero Section') do %>
    #          <section>...</section>
    #        <% end %>
    def cms_section(section, title: nil, page: nil, &block)
      page ||= @page
      render LeanCms::SectionComponent.new(page: page, section: section, title: title), &block
    end

    # Render a CMS section with built-in caching and edit controls
    # Usage: <%= cms_section('hero', title: 'Hero Section') do %>
    #          <section>...</section>
    #        <% end %>
    def cms_section(section, title: nil, page: nil, &block)
      page ||= @page
      render LeanCms::SectionComponent.new(page: page, section: section, title: title), &block
    end

    # Render cards section with component (new API)
    # Usage: <%= cards_section('services_preview', grid_cols: 3) %>
    def cards_section(section, page: nil, **options)
      page ||= @page
      render LeanCms::CardsSectionComponent.new(page: page, section: section, **options)
    end

    # Render bullets section with component (new API)
    # Usage: <%= bullets_section('why_partner') %>
    def bullets_section(section, page: nil, **options)
      page ||= @page
      render LeanCms::BulletsSectionComponent.new(page: page, section: section, **options)
    end

    # Render the Lean CMS admin bar (fixed top strip with Inline Editing
    # toggle, Help, Admin Dashboard, Sign Out). Returns an empty string for
    # signed-out visitors and users without CMS permissions, so it's safe to
    # call unconditionally from your public layout.
    #
    # Usage in your host application.html.erb:
    #
    #   <body class="<%= 'pt-10' if current_user&.has_any_cms_permission? %>">
    #     <%= cms_admin_bar %>
    #     …your header / content…
    #   </body>
    def cms_admin_bar
      render "lean_cms/shared/admin_bar"
    end

    # Render the Google Analytics gtag.js snippet using the measurement ID
    # stored in `LeanCms::Setting.get("google_analytics_id")`. Returns an
    # empty string when the setting is blank — safe to call unconditionally
    # from your layout's <head>.
    #
    # Admins set the ID via /lean-cms/settings without touching code.
    # Example value: "G-XXXXXXXXXX".
    #
    # Usage in your host application.html.erb:
    #   <head>
    #     …
    #     <%= cms_google_analytics_tag %>
    #   </head>
    def cms_google_analytics_tag
      id = LeanCms::Setting.get("google_analytics_id")
      return "".html_safe if id.blank?

      # JSON-encode the ID so a hostile-looking setting value can't break out
      # of the <script>. Setting values are admin-only, but defensive is cheap.
      escaped_id = id.to_s.to_json

      content_tag(:script, "", async: true,
                  src: "https://www.googletagmanager.com/gtag/js?id=#{ERB::Util.url_encode(id)}") +
      content_tag(:script, raw(<<~JS))
        window.dataLayer = window.dataLayer || [];
        function gtag(){dataLayer.push(arguments);}
        gtag('js', new Date());
        gtag('config', #{escaped_id});
      JS
    end

    # Render cards section with partial (legacy method for backward compatibility)
    # Usage: render_cards_section('about', 'certifications_standards')
    def render_cards_section(page, section, **options)
      cards = page_cards(page, section)
      return '' if cards.empty?

      # Get the field record for edit controls
      field = if page.is_a?(LeanCms::Page)
        LeanCms::PageContent.find_by(page_id: page.id, section: section, key: 'cards')
      else
        LeanCms::PageContent.find_by("page = ? AND section = ? AND key = ?", page.to_s, section.to_s, 'cards')
      end
      
      # Check if user can edit
      can_edit = authenticated? && current_user&.has_any_cms_permission? && 
                 LeanCms::Setting.get('in_context_editing', 'true') == 'true'

      render partial: 'shared/cards_section', locals: {
        cards: cards,
        page: page.is_a?(LeanCms::Page) ? page.slug : page.to_s,
        section: section,
        field: field,
        can_edit: can_edit,
        **options
      }
    end

    # Render bullets section with edit controls
    # Usage: render_bullets_section('contact', 'why_partner')
    def render_bullets_section(page, section, **options)
      bullets = page_bullets(page, section)
      return '' if bullets.empty?

      # Get the field record for edit controls
      field = if page.is_a?(LeanCms::Page)
        LeanCms::PageContent.find_by(page_id: page.id, section: section, key: 'bullets')
      else
        LeanCms::PageContent.find_by("page = ? AND section = ? AND key = ?", page.to_s, section.to_s, 'bullets')
      end
      
      # Check if user can edit
      can_edit = authenticated? && current_user&.has_any_cms_permission? && 
                 LeanCms::Setting.get('in_context_editing', 'true') == 'true'

      render partial: 'shared/bullets_section', locals: {
        bullets: bullets,
        page: page.is_a?(LeanCms::Page) ? page.slug : page.to_s,
        section: section,
        field: field,
        can_edit: can_edit,
        **options
      }
    end

    # Wrap a content field with inline editing controls
    # Usage: <%= editable_content('hero', 'heading') %> (uses implicit @page from controller)
    #        <%= editable_content('hero', 'heading', page: other_page) %> (override page)
    #        <%= editable_content('home', 'hero', 'heading') %> (legacy: page as first arg)
    def editable_content(*args, default: nil, tag: :span, page: nil, **html_options)
      if args.length == 3
        page_arg, section, key = args
        page ||= page_arg
      elsif args.length == 2
        section, key = args
        page ||= @page
      else
        raise ArgumentError, "editable_content expects 2 or 3 arguments (section, key) or (page, section, key)"
      end

      render LeanCms::EditableContentComponent.new(
        page: page, section: section, key: key, tag: tag, default: default, **html_options
      )
    end

    # Wrap a section with CMS edit overlay (hover activates edit button linking to section editor).
    # Usage: cms_editable_section(page: 'home', section: 'hero', display_title: 'Hero') do
    #          ... your HTML ...
    #        end
    def cms_editable_section(page:, section:, display_title: nil, &block)
      content = capture(&block)
      return content unless authenticated? && current_user&.has_any_cms_permission?
      return content unless LeanCms::Setting.get('in_context_editing', 'true') == 'true'

      section_title = display_title || section.humanize
      full_title    = "#{page.to_s.titleize} - #{section_title}"
      edit_url      = lean_cms_edit_page_content_path(page: page, section: section)

      content_tag(:div,
        class: 'cms-editable-section',
        data: {
          cms_section: "#{page}/#{section}",
          controller: 'cms-sticky-overlay',
          action: 'mouseenter->cms-sticky-overlay#mouseEnter mouseleave->cms-sticky-overlay#mouseLeave'
        }
      ) do
        concat(content)
        concat(content_tag(:div, class: 'cms-edit-overlay', data: { cms_sticky_overlay_target: 'overlay' }) do
          content_tag(:div, class: 'cms-edit-controls') do
            concat(content_tag(:span, full_title, class: 'cms-section-title'))
            concat(link_to('Edit', edit_url, target: '_blank', class: 'cms-edit-button', data: { turbo: false }))
          end
        end)
      end
    end

    # Like cms_editable_section but links to the Settings page instead of the section editor.
    # Usage: cms_settings_section(display_title: 'Contact Info', anchor: 'site-info') do
    #          ... your HTML ...
    #        end
    def cms_settings_section(display_title:, anchor: nil, &block)
      content = capture(&block)
      return content unless authenticated? && current_user&.has_any_cms_permission?
      return content unless LeanCms::Setting.get('in_context_editing', 'true') == 'true'

      edit_url = lean_cms_settings_path
      edit_url += "##{anchor}" if anchor.present?

      content_tag(:div,
        class: 'cms-editable-section',
        data: {
          cms_section: "settings/#{anchor || 'general'}",
          controller: 'cms-sticky-overlay',
          action: 'mouseenter->cms-sticky-overlay#mouseEnter mouseleave->cms-sticky-overlay#mouseLeave'
        }
      ) do
        concat(content)
        concat(content_tag(:div, class: 'cms-edit-overlay', data: { cms_sticky_overlay_target: 'overlay' }) do
          content_tag(:div, class: 'cms-edit-controls') do
            concat(content_tag(:span, "Settings - #{display_title}", class: 'cms-section-title'))
            concat(link_to('Edit', edit_url, target: '_blank', class: 'cms-edit-button', data: { turbo: false }))
          end
        end)
      end
    end

    # Render a responsive <picture> for an image processed by `lean_cms:optimize_images`.
    #
    # The optimizer produces `<name>-<width>.webp` and `<name>-<width>.<fallback>`
    # variants under app/assets/images/. This helper emits a <picture> with the WebP
    # source and a JPG/PNG fallback img, both with srcset for the configured widths.
    #
    # Usage:
    #   lean_cms_picture_tag("wire-panel", alt: "Wiring", class: "rounded-2xl")
    #   lean_cms_picture_tag("cas-logo", alt: "CAS", format: :png, widths: [128, 256])
    def lean_cms_picture_tag(name, alt:, widths: [640, 1280, 1920], format: :jpg, sizes: "100vw", **img_options)
      fallback_ext = format.to_s
      webp_srcset     = widths.map { |w| "#{asset_path("#{name}-#{w}.webp")} #{w}w" }.join(", ")
      fallback_srcset = widths.map { |w| "#{asset_path("#{name}-#{w}.#{fallback_ext}")} #{w}w" }.join(", ")
      default_width   = widths.max

      content_tag(:picture) do
        concat(tag(:source, type: "image/webp", srcset: webp_srcset, sizes: sizes))
        concat(image_tag("#{name}-#{default_width}.#{fallback_ext}",
                         srcset: fallback_srcset,
                         sizes: sizes,
                         alt: alt,
                         loading: img_options.delete(:loading) || "lazy",
                         decoding: img_options.delete(:decoding) || "async",
                         **img_options))
      end
    end
  end
end
