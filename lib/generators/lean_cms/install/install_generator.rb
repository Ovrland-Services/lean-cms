require "rails/generators"
require "rails/generators/migration"

module LeanCms
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Installs Lean CMS into the host Rails application"

      class_option :user_class, type: :string, default: "User",
        desc: "Name of the user model class (default: User). " \
              "Use --user=Admin or similar if your auth gem (Devise, etc.) uses a different name."

      def self.next_migration_number(dirname)
        next_migration_number = current_migration_number(dirname) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      # Stop before any side effects if the host doesn't have a user model
      # with a matching table yet. The Lean CMS migrations have foreign keys
      # pointing at this table (default `:users`); without it, db:migrate
      # blows up partway through and leaves the database in a half-set-up state.
      def check_user_model
        user_class = options[:user_class]
        table_name = user_class.tableize

        return if ActiveRecord::Base.connection.table_exists?(table_name)

        say "\n#{"=" * 64}", :red
        say "Lean CMS install can't continue.", :red
        say "=" * 64, :red
        say ""
        say "No `#{table_name}` table found in your database."
        say ""
        say "Lean CMS expects an existing #{user_class} model. Set one up first:"
        say ""
        say "  - Rails 8 built-in auth:  bin/rails generate authentication"
        say "  - Devise / Clearance / etc.: install per that gem's instructions"
        say "  - Custom model:  bin/rails generate model #{user_class} ...", :yellow
        say ""
        say "Then run  bin/rails db:migrate  and re-run this generator."
        say ""
        say "If your user model isn't named #{user_class}, pass --user=ClassName:"
        say "  bin/rails generate lean_cms:install --user=Admin"
        say ""
        exit 1
      end

      def copy_initializer
        @user_class = options[:user_class]
        template "lean_cms.rb", "config/initializers/lean_cms.rb"
      end

      def run_migrations
        rake "db:migrate"
      end

      def create_structure_file
        target = File.join(destination_root, "config", "lean_cms_structure.yml")
        return if File.exist?(target)
        template "lean_cms_structure.yml", "config/lean_cms_structure.yml"
      end

      def print_instructions
        say "\n#{"=" * 64}", :green
        say "Lean CMS installed!", :green
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
        say ""
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
        say "   Lean CMS uses LeanCms::Session and LeanCms::MagicLink directly — it does"
        say "   NOT require has_many :sessions or :magic_links on your User. That keeps"
        say "   it compatible with Rails 8's built-in auth and other auth gems."
        say ""
        say "   Required columns on the users table: email_address (string, indexed unique),"
        say "   password_digest, name, active (boolean), must_change_password (boolean),"
        say "   last_login_at (datetime), and permission flags is_super_admin, can_edit_pages,"
        say "   can_edit_blog, can_manage_users, can_access_settings (all booleans)."
        say ""
        say "3. Include Lean CMS in ApplicationController", :yellow
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
