namespace :lean_cms do
  desc "Load page content structure from YAML file"
  task load_structure: :environment do
    require 'yaml'

    structure_file = Rails.root.join('config', 'lean_cms_structure.yml')
    unless File.exist?(structure_file)
      puts "Error: Structure file not found at #{structure_file}"
      exit 1
    end

    structure = YAML.load_file(structure_file)
    pages = structure['pages'] || {}

    if pages.empty?
      puts "Warning: No pages defined in structure file"
      exit 0
    end

    # Find a system user for last_edited_by
    system_user = User.cms_admin.first || User.first
    unless system_user
      puts "Error: No users found in database. Please create at least one user first."
      exit 1
    end

    puts "Loading LeanCMS page content structure..."
    puts "Using system user: #{system_user.email_address}"
    puts "=" * 60

    total_fields = 0
    created_count = 0
    updated_count = 0
    skipped_count = 0

    pages.each do |page_key, page_data|
      sections = page_data['sections'] || {}
      page_display_title = page_data['display_title'] || page_key.titleize
      page_order = page_data['page_order'] || 0

      puts "\nPage: #{page_key.upcase} (#{page_display_title}) [order: #{page_order}]"

      sections.each do |section_key, section_data|
        # Extract section metadata
        section_display_title = section_data['display_title'] || section_key.titleize
        section_order = section_data['section_order'] || 0
        fields = section_data['fields'] || {}
        cards_data = section_data['cards']

        puts "  Section: #{section_key} (#{section_display_title}) [order: #{section_order}]"

        # Process regular fields
        fields.each do |field_key, field_data|
          next unless field_data.is_a?(Hash) && field_data['type']

          total_fields += 1

          content_record = LeanCms::PageContent.find_or_initialize_by(
            page: page_key,
            section: section_key,
            key: field_key
          )

          # Set attributes
          content_record.label = field_data['label']
          content_record.content_type = field_data['type']
          content_record.display_title = section_display_title
          content_record.page_display_title = page_display_title
          content_record.page_order = page_order
          content_record.section_order = section_order

          # Set default value only if record is new
          if content_record.new_record?
            default_value = field_data['default']
            if content_record.rich_text?
              content_record.rich_content = default_value
            elsif content_record.boolean?
              content_record.value = (default_value == true || default_value == 'true').to_s
            else
              content_record.value = default_value.to_s if default_value
            end
          end

          # Set options for dropdown fields
          if content_record.dropdown? && field_data['options']
            content_record.options = { 'options' => field_data['options'] }
          end

          # Store max_length in options if specified
          if field_data['max_length']
            content_record.options ||= {}
            content_record.options = content_record.options.merge('max_length' => field_data['max_length'].to_i)
          end

          # Set position if specified
          content_record.position = field_data['position'] || 0

          # Set last_edited_by
          content_record.last_edited_by = system_user

          if content_record.new_record?
            if content_record.save
              created_count += 1
              puts "    ✓ Created: #{field_key} (#{field_data['type']})"
            else
              puts "    ✗ Error: #{field_key} - #{content_record.errors.full_messages.join(', ')}"
            end
          elsif content_record.changed?
            if content_record.save
              updated_count += 1
              puts "    ↻ Updated: #{field_key} (#{field_data['type']})"
            else
              puts "    ✗ Error: #{field_key} - #{content_record.errors.full_messages.join(', ')}"
            end
          else
            skipped_count += 1
            puts "    - Skipped: #{field_key} (already exists)"
          end
        end

        # Process cards if present
        if cards_data && cards_data['items']
          total_fields += 1

          card_record = LeanCms::PageContent.find_or_initialize_by(
            page: page_key,
            section: section_key,
            key: 'cards'
          )

          card_record.label = "Cards"
          card_record.content_type = 'cards'
          card_record.display_title = section_display_title
          card_record.page_display_title = page_display_title
          card_record.page_order = page_order
          card_record.section_order = section_order
          card_record.position = 999  # Cards typically come last in a section

          # Store card items and max_cards in options
          card_record.options = {
            'max_cards' => cards_data['max_cards'],
            'type' => cards_data['type']
          }

          # Store cards as JSON in content (default) only if new record
          if card_record.new_record?
            card_record.content = cards_data['items'].to_json
          end

          card_record.last_edited_by = system_user

          if card_record.new_record?
            if card_record.save
              created_count += 1
              puts "    ✓ Created: cards (#{cards_data['items'].count} items)"
            else
              puts "    ✗ Error: cards - #{card_record.errors.full_messages.join(', ')}"
            end
          elsif card_record.changed?
            if card_record.save
              updated_count += 1
              puts "    ↻ Updated: cards"
            else
              puts "    ✗ Error: cards - #{card_record.errors.full_messages.join(', ')}"
            end
          else
            skipped_count += 1
            puts "    - Skipped: cards (already exists)"
          end
        end

        # Process bullets if present (similar to cards, but simpler)
        if (bullets_data = section_data['bullets']) && bullets_data['items']
          total_fields += 1

          bullet_record = LeanCms::PageContent.find_or_initialize_by(
            page: page_key,
            section: section_key,
            key: 'bullets'
          )

          bullet_record.label = "Bullet Points"
          bullet_record.content_type = 'bullets'
          bullet_record.display_title = section_display_title
          bullet_record.page_display_title = page_display_title
          bullet_record.page_order = page_order
          bullet_record.section_order = section_order
          bullet_record.position = 999

          # Store max_items in options
          bullet_record.options = {
            'max_items' => bullets_data['max_items'] || 10,
            'type' => 'bullets'
          }

          # Store bullets as JSON array in content (only if new record)
          if bullet_record.new_record?
            bullet_record.content = bullets_data['items'].to_json
          end

          bullet_record.last_edited_by = system_user

          if bullet_record.new_record?
            if bullet_record.save
              created_count += 1
              puts "    ✓ Created: bullets (#{bullets_data['items'].count} items)"
            else
              puts "    ✗ Error: bullets - #{bullet_record.errors.full_messages.join(', ')}"
            end
          elsif bullet_record.changed?
            if bullet_record.save
              updated_count += 1
              puts "    ↻ Updated: bullets"
            else
              puts "    ✗ Error: bullets - #{bullet_record.errors.full_messages.join(', ')}"
            end
          else
            skipped_count += 1
            puts "    - Skipped: bullets (already exists)"
          end
        end
      end
    end

    puts "\n" + "=" * 60
    puts "Summary:"
    puts "  Total fields: #{total_fields}"
    puts "  Created: #{created_count}"
    puts "  Updated: #{updated_count}"
    puts "  Skipped: #{skipped_count}"
    puts "=" * 60
  end

  desc "Clear all page content (WARNING: destructive)"
  task clear_content: :environment do
    print "Are you sure you want to delete ALL page content? (yes/no): "
    confirmation = STDIN.gets.chomp

    if confirmation.downcase == 'yes'
      count = LeanCms::PageContent.count
      LeanCms::PageContent.destroy_all
      puts "Deleted #{count} page content records"
    else
      puts "Operation cancelled"
    end
  end

  desc "Reload structure (clear and load)"
  task reload_structure: :environment do
    Rake::Task['lean_cms:clear_content'].invoke
    Rake::Task['lean_cms:load_structure'].invoke
  end

  desc "Show page content stats"
  task stats: :environment do
    puts "LeanCMS Page Content Statistics"
    puts "=" * 60

    pages = LeanCms::PageContent.distinct.pluck(:page)

    pages.each do |page|
      sections = LeanCms::PageContent.where(page: page).distinct.pluck(:section)
      total_fields = LeanCms::PageContent.where(page: page).count

      puts "\nPage: #{page.upcase}"
      puts "  Sections: #{sections.count}"
      puts "  Total fields: #{total_fields}"

      sections.each do |section|
        field_count = LeanCms::PageContent.where(page: page, section: section).count
        puts "    - #{section}: #{field_count} fields"
      end
    end

    puts "\n" + "=" * 60
    puts "Total: #{LeanCms::PageContent.count} content fields across #{pages.count} pages"
    puts "=" * 60
  end

  # ============================================================================
  # Content Sync Tasks
  # These tasks enable a safe workflow for syncing SQLite database between
  # local development and production environments.
  # ============================================================================

  namespace :sync do
    desc "Lock content editing on this instance"
    task lock: :environment do
      reason = ENV['REASON'] || 'Content sync in progress'

      if LeanCms::Setting.content_locked?
        puts "Content is already locked."
        lock_info = LeanCms::Setting.content_lock_info
        puts "  Locked at: #{lock_info[:locked_at]}"
        puts "  Reason: #{lock_info[:reason]}"
      else
        LeanCms::Setting.lock_content!(reason)
        puts "Content editing has been LOCKED."
        puts "  Reason: #{reason}"
        puts "  Locked at: #{Time.current}"
        puts "\nEditors will not be able to make changes until unlocked."
      end
    end

    desc "Unlock content editing on this instance"
    task unlock: :environment do
      if LeanCms::Setting.content_locked?
        LeanCms::Setting.unlock_content!
        puts "Content editing has been UNLOCKED."
        puts "Editors can now make changes."
      else
        puts "Content is not locked."
      end
    end

    desc "Show current lock status"
    task status: :environment do
      if LeanCms::Setting.content_locked?
        lock_info = LeanCms::Setting.content_lock_info
        puts "Content Status: LOCKED"
        puts "  Locked at: #{lock_info[:locked_at]}"
        puts "  Reason: #{lock_info[:reason]}"
      else
        puts "Content Status: UNLOCKED"
        puts "Editors can make changes."
      end
    end

    desc "Pull production database to local (run locally)"
    task pull: :environment do
      require_relative '../lean_cms/sync_helper'
      LeanCms::SyncHelper.pull_from_production
    end

    desc "Push local database to production (run locally)"
    task push: :environment do
      require_relative '../lean_cms/sync_helper'
      LeanCms::SyncHelper.push_to_production
    end

    desc "Stage development DB as production_local for local production testing"
    task stage: :environment do
      dev_db    = Rails.root.join('storage', 'development.sqlite3').to_s
      prod_local = Rails.root.join('storage', 'production_local.sqlite3').to_s

      unless File.exist?(dev_db)
        abort "Development database not found at #{dev_db}"
      end

      puts "Staging development DB for local production testing..."
      puts "=" * 60

      # Checkpoint WAL on the dev DB first so the copy is consistent
      puts "  Checkpointing development database..."
      system("sqlite3 #{dev_db} 'PRAGMA wal_checkpoint(TRUNCATE);'")
      FileUtils.rm_f("#{dev_db}-shm")
      FileUtils.rm_f("#{dev_db}-wal")

      # Back up any existing production_local
      if File.exist?(prod_local)
        backup = "#{prod_local}.backup.#{Time.now.strftime('%Y%m%d_%H%M%S')}"
        FileUtils.cp(prod_local, backup)
        puts "  Backed up existing production_local to: #{File.basename(backup)}"
      end

      FileUtils.cp(dev_db, prod_local)
      FileUtils.rm_f("#{prod_local}-shm")
      FileUtils.rm_f("#{prod_local}-wal")

      puts "  Copied development.sqlite3 → production_local.sqlite3"
      puts "\n" + "=" * 60
      puts "Done! Start Rails in production mode against the local DB:"
      puts ""
      puts "  RAILS_ENV=production DATABASE_URL=sqlite3:storage/production_local.sqlite3 bin/rails server"
      puts ""
      puts "When happy with the result, push to the real server:"
      puts ""
      puts "  bin/rails lean_cms:sync:push"
      puts "=" * 60
    end

    desc "Full sync workflow: lock -> pull -> (make changes) -> push -> unlock"
    task :workflow do
      puts "LeanCMS Content Sync Workflow"
      puts "=" * 60
      puts "\nNew project / first deploy:"
      puts "  1. Develop in development DB (default)"
      puts "  2. Stage for local production test:  bin/rails lean_cms:sync:stage"
      puts "  3. Start production server locally:  RAILS_ENV=production DATABASE_URL=sqlite3:storage/production_local.sqlite3 bin/rails server"
      puts "  4. Push to real server:              bin/rails lean_cms:sync:push"
      puts ""
      puts "Ongoing sync workflow:"
      puts "  1. Lock production:     bin/kamal cms-lock"
      puts "  2. Pull database:       bin/rails lean_cms:sync:pull"
      puts "  3. Make local changes"
      puts "  4. Push database:       bin/rails lean_cms:sync:push"
      puts "  5. Unlock production:   bin/kamal cms-unlock"
      puts "\nOr use the combined commands:"
      puts "  bin/rails lean_cms:sync:start  - Lock and pull"
      puts "  bin/rails lean_cms:sync:finish - Push and unlock"
      puts "=" * 60
    end

    desc "Start sync: lock production and pull database"
    task start: :environment do
      puts "Starting content sync workflow..."
      puts "=" * 60

      # Lock production via Kamal
      puts "\n1. Locking production..."
      system("kamal app exec 'bin/rails lean_cms:sync:lock'") || abort("Failed to lock production")

      # Pull database
      puts "\n2. Pulling production database..."
      Rake::Task['lean_cms:sync:pull'].invoke

      puts "\n" + "=" * 60
      puts "Sync started! Production is locked."
      puts "Make your changes locally, then run: bin/rails lean_cms:sync:finish"
      puts "=" * 60
    end

    desc "Finish sync: push database and unlock production"
    task finish: :environment do
      puts "Finishing content sync workflow..."
      puts "=" * 60

      # Push database
      puts "\n1. Pushing local database to production..."
      Rake::Task['lean_cms:sync:push'].invoke

      # Unlock production via Kamal
      puts "\n2. Unlocking production..."
      system("kamal app exec 'bin/rails lean_cms:sync:unlock'") || abort("Failed to unlock production")

      puts "\n" + "=" * 60
      puts "Sync complete! Production is unlocked and updated."
      puts "=" * 60
    end
  end

  desc "Optimize images: generate WebP + fallback variants from app/assets/images/source/"
  task optimize_images: :environment do
    require "image_processing/vips"

    source_dir = Rails.root.join("app/assets/images/source")
    output_dir = Rails.root.join("app/assets/images")

    unless source_dir.directory?
      puts "No source directory at #{source_dir}."
      puts "Create app/assets/images/source/, place originals there, and re-run."
      exit 0
    end

    widths       = (ENV["WIDTHS"]       || "640,1280,1920").split(",").map(&:to_i)
    webp_quality = (ENV["WEBP_QUALITY"] || "80").to_i
    jpeg_quality = (ENV["JPEG_QUALITY"] || "85").to_i
    written = skipped = 0

    Dir.glob(source_dir.join("*.{jpg,jpeg,png,JPG,JPEG,PNG}")).sort.each do |source|
      base       = File.basename(source, ".*")
      source_ext = File.extname(source).delete(".").downcase
      fallback   = source_ext == "jpeg" ? "jpg" : source_ext
      src_kb     = File.size(source) / 1024

      puts "#{base} (#{src_kb} KB #{source_ext})"

      widths.each do |w|
        [["webp", webp_quality], [fallback, fallback == "jpg" ? jpeg_quality : nil]].each do |fmt, q|
          out = output_dir.join("#{base}-#{w}.#{fmt}")
          if out.exist? && out.mtime >= File.mtime(source)
            skipped += 1
            next
          end

          pipeline = ImageProcessing::Vips.source(source).resize_to_limit(w, nil)
          pipeline = pipeline.saver(quality: q) if q
          pipeline.convert(fmt).call(destination: out.to_s)

          puts "  -> #{w}w #{fmt.upcase}: #{File.size(out) / 1024} KB"
          written += 1
        end
      end
    end

    puts ""
    puts "Wrote #{written} files, skipped #{skipped} up-to-date."
  end
end
