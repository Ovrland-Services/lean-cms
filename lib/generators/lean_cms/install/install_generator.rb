require "rails/generators"
require "rails/generators/migration"

module LeanCms
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Installs LeanCMS into the host Rails application"

      def self.next_migration_number(dirname)
        next_migration_number = current_migration_number(dirname) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      def copy_initializer
        template "lean_cms.rb", "config/initializers/lean_cms.rb"
      end

      def run_migrations
        rake "db:migrate"
      end

      def create_structure_file
        unless File.exist?(destination_root.join("config/lean_cms_structure.yml"))
          template "lean_cms_structure.yml", "config/lean_cms_structure.yml"
        end
      end

      def print_instructions
        say "\n#{"=" * 60}", :green
        say "LeanCMS installed successfully!", :green
        say "=" * 60, :green
        say ""
        say "Next steps:"
        say "  1. Edit config/initializers/lean_cms.rb with your site details"
        say "  2. Create an admin user:  rails runner \"User.create!(email_address: 'admin@example.com', password: 'password', role: :cms_admin)\""
        say "  3. Seed content structure: rails lean_cms:load_structure"
        say "  4. Start the server and visit /lean-cms"
        say ""
        say "Optional: install demo pages with:  rails generate lean_cms:demo"
        say ""
      end
    end
  end
end
