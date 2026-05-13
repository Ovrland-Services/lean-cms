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
        say "\n#{"=" * 64}", :green
        say "LeanCMS installed!", :green
        say "=" * 64, :green
        say ""
        say "1. Configure your site", :yellow
        say "   Edit config/initializers/lean_cms.rb — site name, logo, colors,"
        say "   admin path, mailer_from."
        say ""
        say "2. Wire up your User model", :yellow
        say "   app/models/user.rb needs:"
        say ""
        say "     class User < ApplicationRecord"
        say "       has_secure_password"
        say "       has_many :sessions,    class_name: \"LeanCms::Session\",    dependent: :destroy"
        say "       has_many :magic_links, class_name: \"LeanCms::MagicLink\",  dependent: :destroy"
        say "       # Permission predicates that fall back to is_super_admin?:"
        say "       def can_edit_pages?;      is_super_admin? || can_edit_pages;      end"
        say "       def can_edit_blog?;       is_super_admin? || can_edit_blog;       end"
        say "       def can_manage_users?;    is_super_admin? || can_manage_users;    end"
        say "       def can_access_settings?; is_super_admin? || can_access_settings; end"
        say "       def has_any_cms_permission?"
        say "         can_edit_pages? || can_edit_blog? || can_manage_users? || can_access_settings?"
        say "       end"
        say "       def record_login!; update_column(:last_login_at, Time.current); end"
        say "       def active?;             active;             end"
        say "       def must_change_password?; must_change_password; end"
        say "     end"
        say ""
        say "   Required columns on the users table: email_address (string, indexed unique),"
        say "   password_digest, name, active (boolean), must_change_password (boolean),"
        say "   last_login_at (datetime), and permission flags is_super_admin, can_edit_pages,"
        say "   can_edit_blog, can_manage_users, can_access_settings (all booleans)."
        say ""
        say "3. Include LeanCMS in ApplicationController", :yellow
        say "   class ApplicationController < ActionController::Base"
        say "     include LeanCms::Authentication"
        say "     include Pundit::Authorization"
        say "   end"
        say ""
        say "4. Include the helper in ApplicationHelper", :yellow
        say "   module ApplicationHelper"
        say "     include LeanCms::PageContentHelper"
        say "   end"
        say ""
        say "5. Seed your site structure", :yellow
        say "   Edit config/lean_cms_structure.yml, then:"
        say "     bin/rails lean_cms:load_structure"
        say ""
        say "6. Create your first admin", :yellow
        say "   bin/rails runner 'User.create!(email_address: \"admin@example.com\", password: \"change-me\", name: \"Admin\", active: true, is_super_admin: true)'"
        say ""
        say "7. Start the server and log in", :yellow
        say "   bin/dev   (or  rails server)"
        say "   Visit  /lean-cms/login"
        say ""
        say "Optional: install demo pages — bin/rails generate lean_cms:demo", :cyan
        say ""
        say "Full docs: https://leancms.dev/docs/getting-started/", :cyan
        say ""
      end
    end
  end
end
