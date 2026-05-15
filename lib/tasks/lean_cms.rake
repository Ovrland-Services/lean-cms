namespace :lean_cms do
  # Plain-text stdout logger for the Rake tasks — no timestamps or severity
  # tags, since these are interactive CLI commands. Background-job callers
  # use Rails.logger (or whatever they pass in) instead.
  rake_logger = lambda do
    logger = ActiveSupport::Logger.new($stdout)
    logger.formatter = ->(_severity, _time, _progname, msg) { "#{msg}\n" }
    logger
  end

  desc "Load page content structure from YAML file"
  task load_structure: :environment do
    LeanCms::Loader.new(logger: rake_logger.call).load!
  rescue LeanCms::Loader::StructureFileMissing => e
    warn "Error: #{e.message}"
    exit 1
  rescue LeanCms::Loader::NoUsersFound => e
    warn "Error: #{e.message} Run `bin/rails generate authentication` (or your auth gem's install) first."
    exit 1
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

  desc "Export current LeanCms::PageContent records to YAML (config/lean_cms_structure_export.yml)"
  task export_structure: :environment do
    require "yaml"

    output_path = ENV["OUTPUT"] || Rails.root.join("config", "lean_cms_structure_export.yml").to_s

    pages_yaml = {}

    page_keys = LeanCms::PageContent.distinct.order(:page_order, :page).pluck(:page)

    page_keys.each do |page_key|
      page_scope = LeanCms::PageContent.where(page: page_key)
      first = page_scope.order(:page_order).first

      page_yaml = {
        "display_title" => first.page_display_title.presence || page_key.titleize,
        "page_order"    => first.page_order || 0,
        "sections"      => {}
      }

      section_keys = page_scope.distinct.order(:section_order, :section).pluck(:section)
      section_keys.each do |section_key|
        section_scope = page_scope.where(section: section_key)
        section_first = section_scope.order(:section_order).first

        section_yaml = {
          "display_title" => section_first.display_title.presence || section_key.titleize,
          "section_order" => section_first.section_order || 0,
          "fields"        => {}
        }

        section_scope.order(:position, :key).each do |record|
          case record.content_type
          when "cards"
            items = JSON.parse(record.content.to_s) rescue []
            section_yaml["cards"] = {
              "type"      => "cards",
              "max_cards" => record.options.is_a?(Hash) ? record.options["max_cards"] : nil,
              "items"     => items
            }.compact
          when "bullets"
            items = JSON.parse(record.content.to_s) rescue []
            section_yaml["bullets"] = {
              "type"      => "bullets",
              "max_items" => record.options.is_a?(Hash) ? record.options["max_items"] : nil,
              "items"     => items
            }.compact
          else
            field_yaml = { "type" => record.content_type }
            field_yaml["label"]     = record.label    if record.label.present?
            field_yaml["position"]  = record.position if record.position.to_i != 0

            # Current production value becomes the seeded default in fresh environments.
            field_yaml["default"] =
              if record.content_type == "rich_text"
                record.rich_content&.to_s
              elsif record.content_type == "boolean"
                record.value == "true"
              else
                record.value
              end

            field_yaml.compact!

            if record.options.is_a?(Hash)
              field_yaml["max_length"] = record.options["max_length"] if record.options["max_length"]
              field_yaml["options"]    = record.options["options"]    if record.options["options"]
            end

            section_yaml["fields"][record.key] = field_yaml
          end
        end

        page_yaml["sections"][section_key] = section_yaml
      end

      pages_yaml[page_key] = page_yaml
    end

    File.write(output_path, { "pages" => pages_yaml }.to_yaml)
    puts "Exported #{LeanCms::PageContent.count} content records across #{page_keys.size} pages to:"
    puts "  #{output_path}"
    puts ""
    puts "Note: image attachments are not included in the YAML export. Re-attach them"
    puts "      via the CMS UI or copy ActiveStorage blobs separately."
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

  # Guard for sync tasks that copy SQLite database files directly
  # (pull / push / stage / start / finish). Lock / unlock / status are
  # adapter-agnostic and don't need this — they only toggle a Setting.
  sqlite_only = lambda do
    adapter = ActiveRecord::Base.connection_db_config.adapter
    return if adapter == "sqlite3"

    warn <<~MSG
      lean_cms:sync:* file-copy tasks (pull / push / stage / start / finish)
      assume a SQLite database. The current connection uses #{adapter.inspect}.

      Use your database's native dump/restore tooling instead:
        Postgres:  pg_dump / pg_restore
        MySQL:     mysqldump

      The lock / unlock / status tasks work on any adapter and remain available.
    MSG
    exit 1
  end

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

    desc "Pull production database to local (run locally, SQLite only)"
    task pull: :environment do
      sqlite_only.call
      require_relative '../lean_cms/sync_helper'
      LeanCms::SyncHelper.pull_from_production
    end

    desc "Push local database to production (run locally, SQLite only)"
    task push: :environment do
      sqlite_only.call
      require_relative '../lean_cms/sync_helper'
      LeanCms::SyncHelper.push_to_production
    end

    desc "Stage development DB as production_local for local production testing (SQLite only)"
    task stage: :environment do
      sqlite_only.call

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

    desc "Start sync: lock production and pull database (SQLite only)"
    task start: :environment do
      sqlite_only.call
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

    desc "Finish sync: push database and unlock production (SQLite only)"
    task finish: :environment do
      sqlite_only.call
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

    Dir.glob(source_dir.join("*.{jpg,jpeg,png}"), File::FNM_CASEFOLD).uniq.sort.each do |source|
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
