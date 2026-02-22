module LeanCms
  class SyncHelper
    class << self
      def config
        @config ||= load_config
      end

      def pull_from_production
        puts "Pulling production database..."

        validate_config!
        ensure_local_dir_exists

        # Stop the container to ensure clean database state
        puts "  Stopping production container..."
        run_ssh("docker stop $(docker ps -q --filter name=#{config[:service]}-web) 2>/dev/null || true")

        # Pull the database file
        puts "  Downloading production.sqlite3..."
        run_local("scp #{config[:ssh_user]}@#{config[:server]}:#{config[:remote_storage_path]}/production.sqlite3 #{local_db_path}")

        # Also pull Active Storage files if they exist
        puts "  Downloading Active Storage files..."
        run_local("scp -r #{config[:ssh_user]}@#{config[:server]}:#{config[:remote_storage_path]}/ #{local_storage_path}/ 2>/dev/null || true")

        # Restart the container
        puts "  Restarting production container..."
        run_ssh("docker start $(docker ps -aq --filter name=#{config[:service]}-web) 2>/dev/null || true")

        # Clean up WAL files locally (they're from production)
        cleanup_wal_files(local_db_path)

        puts "\nDatabase pulled successfully!"
        puts "  Local path: #{local_db_path}"
        puts "\nYou can now make changes locally using:"
        puts "  RAILS_ENV=production_local bin/rails console"
      end

      def push_to_production
        puts "Pushing local database to production..."

        validate_config!
        validate_local_db_exists!

        # Checkpoint the local database (flush WAL to main file)
        checkpoint_database(local_db_path)

        # Stop the container
        puts "  Stopping production container..."
        run_ssh("docker stop $(docker ps -q --filter name=#{config[:service]}-web) 2>/dev/null || true")

        # Backup production database first
        timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
        puts "  Backing up production database..."
        run_ssh("cp #{config[:remote_storage_path]}/production.sqlite3 #{config[:remote_storage_path]}/production.sqlite3.backup.#{timestamp} 2>/dev/null || true")

        # Push the database file
        puts "  Uploading production.sqlite3..."
        run_local("scp #{local_db_path} #{config[:ssh_user]}@#{config[:server]}:#{config[:remote_storage_path]}/production.sqlite3")

        # Push Active Storage files
        puts "  Uploading Active Storage files..."
        run_local("scp -r #{local_storage_path}/* #{config[:ssh_user]}@#{config[:server]}:#{config[:remote_storage_path]}/ 2>/dev/null || true")

        # Clean up WAL files on server
        puts "  Cleaning up WAL files..."
        run_ssh("rm -f #{config[:remote_storage_path]}/production.sqlite3-shm #{config[:remote_storage_path]}/production.sqlite3-wal")

        # Restart the container
        puts "  Restarting production container..."
        run_ssh("docker start $(docker ps -aq --filter name=#{config[:service]}-web) 2>/dev/null || true")

        puts "\nDatabase pushed successfully!"
        puts "  Backup saved as: production.sqlite3.backup.#{timestamp}"

        clear_production_cache
        warm_cache
      end

      private

      def load_config
        deploy_config = YAML.load_file(Rails.root.join('config', 'deploy.yml'))

        server = deploy_config.dig('servers', 'web')&.first
        service = deploy_config['service']
        ssh_user = deploy_config.dig('ssh', 'user') || 'root'
        host = deploy_config.dig('proxy', 'host')
        ssl = deploy_config.dig('proxy', 'ssl') != false

        {
          server: server,
          service: service,
          ssh_user: ssh_user,
          host: host,
          base_url: "#{ssl ? 'https' : 'http'}://#{host}",
          remote_storage_path: "/var/lib/docker/volumes/#{service}_storage/_data",
          local_storage_path: Rails.root.join('storage').to_s
        }
      end

      def validate_config!
        raise "No server configured in config/deploy.yml" unless config[:server]
        raise "No service name configured in config/deploy.yml" unless config[:service]
      end

      def validate_local_db_exists!
        raise "Local database not found at #{local_db_path}" unless File.exist?(local_db_path)
      end

      def ensure_local_dir_exists
        FileUtils.mkdir_p(local_storage_path)
      end

      def local_db_path
        Rails.root.join('storage', 'production_local.sqlite3').to_s
      end

      def local_storage_path
        Rails.root.join('storage').to_s
      end

      def run_ssh(command)
        full_command = "ssh #{config[:ssh_user]}@#{config[:server]} \"#{command}\""
        result = system(full_command)
        raise "SSH command failed: #{command}" unless result
        result
      end

      def run_local(command)
        result = system(command)
        raise "Local command failed: #{command}" unless result
        result
      end

      def cleanup_wal_files(db_path)
        FileUtils.rm_f("#{db_path}-shm")
        FileUtils.rm_f("#{db_path}-wal")
      end

      def clear_production_cache
        puts "\nClearing production cache..."
        puts "  Waiting for container to become healthy..."
        sleep 5

        run_ssh(
          "docker exec $(docker ps -q --filter name=#{config[:service]}-web) " \
          "bin/rails runner 'Rails.cache.clear' 2>/dev/null || true"
        )
        puts "  Cache cleared."
      end

      def warm_cache
        base_url = config[:base_url]
        return unless base_url.present?

        pages = %w[/ /services /about /contact /blog /portfolio]

        puts "\nWarming cache..."
        puts "  Waiting for container to become healthy..."
        sleep 5

        pages.each do |path|
          url = "#{base_url}#{path}"
          code = `curl -s -o /dev/null -w "%{http_code}" --max-time 15 "#{url}"`.strip
          status = code == "200" ? "✓" : "✗"
          puts "  #{status}  #{code}  #{url}"
        end

        puts "Cache warmed."
      end

      def checkpoint_database(db_path)
        return unless File.exist?(db_path)

        puts "  Checkpointing local database..."
        system("sqlite3 #{db_path} 'PRAGMA wal_checkpoint(TRUNCATE);'")
        cleanup_wal_files(db_path)
      end
    end
  end
end
