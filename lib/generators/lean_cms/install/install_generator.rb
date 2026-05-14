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
      # with a matching table yet, or the existing table is missing the base
      # columns (email_address, password_digest) Lean CMS hard-codes against.
      def check_user_model
        user_class = options[:user_class]
        table_name = user_class.tableize

        unless ActiveRecord::Base.connection.table_exists?(table_name)
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

        existing = ActiveRecord::Base.connection.columns(table_name).map(&:name)
        required_base = %w[email_address password_digest]
        missing_base = required_base - existing

        return if missing_base.empty?

        say "\n#{"=" * 64}", :red
        say "Lean CMS install can't continue.", :red
        say "=" * 64, :red
        say ""
        say "The `#{table_name}` table is missing required columns: #{missing_base.join(", ")}."
        say ""
        say "Lean CMS authenticates with `#{user_class}.authenticate_by(email_address:, password:)`,"
        say "so both `email_address` and `password_digest` columns are required."
        say ""
        say "Add them yourself (rename `email` -> `email_address` if you have it, etc.) and re-run."
        say ""
        exit 1
      end

      # Detect Rails 8's built-in auth (`bin/rails generate authentication`)
      # and warn — it conflicts with Lean CMS's Authentication concern.
      # Both define `before_action :require_authentication`, and the
      # last-included wins. Without manual cleanup, /lean-cms protected
      # routes redirect to /session/new (Rails 8's) instead of /lean-cms/login.
      def check_for_rails_auth_conflict
        ac_path = File.join(destination_root, "app", "controllers", "application_controller.rb")
        return unless File.exist?(ac_path)
        return unless File.read(ac_path).match?(/^\s*include\s+Authentication\s*$/)

        say "\n#{"=" * 64}", :yellow
        say "WARNING: Rails 8 authentication detected.", :yellow
        say "=" * 64, :yellow
        say ""
        say "app/controllers/application_controller.rb already includes Rails 8's"
        say "built-in Authentication concern. That conflicts with Lean CMS auth:"
        say "both define `before_action :require_authentication`, and the"
        say "last-included one wins. As-is, /lean-cms admin routes will redirect"
        say "to /session/new (Rails 8's login) instead of /lean-cms/login."
        say ""
        say "After this install completes, clean up Rails 8 auth so Lean CMS owns auth:"
        say ""
        say "  1. In app/controllers/application_controller.rb:"
        say "       Remove:  include Authentication", :red
        say "       Keep:    include LeanCms::Authentication", :green
        say ""
        say "  2. Delete the Rails-8-generated auth files (Lean CMS replaces them):"
        say "       app/controllers/sessions_controller.rb", :cyan
        say "       app/controllers/passwords_controller.rb", :cyan
        say "       app/controllers/concerns/authentication.rb", :cyan
        say "       app/models/session.rb", :cyan
        say "       app/models/current.rb", :cyan
        say "       app/views/sessions/", :cyan
        say "       app/views/passwords/", :cyan
        say "       app/views/passwords_mailer/", :cyan
        say "       app/mailers/passwords_mailer.rb", :cyan
        say "       test/controllers/sessions_controller_test.rb", :cyan
        say "       test/controllers/passwords_controller_test.rb", :cyan
        say ""
        say "  3. Remove the Rails 8 auth routes from config/routes.rb:"
        say "       resource :session", :red
        say "       resources :passwords, param: :token", :red
        say ""
        say "Lean CMS provides all of this functionality under /lean-cms/."
        say "Continuing the install — you'll see this WARNING again at the end."
        say "#{"=" * 64}", :yellow
        say ""
      end

      # Generate a migration that adds the Lean CMS-specific columns the host
      # user table doesn't already have (name, active, permission flags, …).
      # Silently skips if everything's already in place. The migration runs
      # as part of `db:migrate` in `run_migrations` below.
      def add_missing_user_columns
        user_class = options[:user_class]
        @user_table = user_class.tableize
        existing = ActiveRecord::Base.connection.columns(@user_table).map(&:name)

        required = [
          [:name,                 :string,   {}],
          [:active,               :boolean,  { default: true,  null: false }],
          [:must_change_password, :boolean,  { default: false, null: false }],
          [:last_login_at,        :datetime, {}],
          [:is_super_admin,       :boolean,  { default: false, null: false }],
          [:can_edit_pages,       :boolean,  { default: false, null: false }],
          [:can_edit_blog,        :boolean,  { default: false, null: false }],
          [:can_manage_users,     :boolean,  { default: false, null: false }],
          [:can_access_settings,  :boolean,  { default: false, null: false }]
        ]

        @missing_columns = required.reject { |name, _, _| existing.include?(name.to_s) }
        return if @missing_columns.empty?

        say "Generating migration to add Lean CMS columns to `#{@user_table}` " \
            "(#{@missing_columns.map(&:first).join(", ")})...", :yellow
        migration_template "add_lean_cms_columns_to_users.rb.tt",
                           "db/migrate/add_lean_cms_columns_to_#{@user_table}.rb"
      end

      def copy_initializer
        @user_class = options[:user_class]
        template "lean_cms.rb", "config/initializers/lean_cms.rb"
      end

      # Inject the engine's Tailwind sources into the host's Tailwind input file
      # so utilities referenced from gem views/controllers actually get emitted.
      # tailwindcss-rails' `tailwindcss:engines` task generates
      # app/assets/builds/tailwind/lean_cms.css (a thin wrapper that @imports the
      # gem's engine.css with absolute paths), but the host has to opt in by
      # @import-ing that bundle file from its own application.css.
      def wire_tailwind
        tailwind_input = File.join(destination_root, "app/assets/tailwind/application.css")
        unless File.exist?(tailwind_input)
          say "Skipping Tailwind wire-up — no app/assets/tailwind/application.css found.", :yellow
          say "  If you use Tailwind, add this line to your Tailwind input file:", :yellow
          say "    @import \"../builds/tailwind/lean_cms.css\";", :cyan
          return
        end

        contents = File.read(tailwind_input)
        if contents.include?("builds/tailwind/lean_cms.css")
          say "Tailwind input already imports lean_cms engine — skipping.", :cyan
          return
        end

        say "Adding lean_cms engine @import to app/assets/tailwind/application.css", :green
        append_to_file tailwind_input, <<~CSS

          /* Lean CMS engine Tailwind sources (auto-generated by tailwindcss:engines). */
          @import "../builds/tailwind/lean_cms.css";
        CSS
      end

      # Add `import "trix"` + `import "@rails/actiontext"` to the host's
      # application.js so the field-editor modal's Trix editor loads for
      # rich_text fields. The gem's own importmap.rb already pins them;
      # this step is just the import line in the host entry point.
      def wire_actiontext_imports
        app_js = File.join(destination_root, "app/javascript/application.js")
        unless File.exist?(app_js)
          say "Skipping Action Text JS wire-up — no app/javascript/application.js found.", :yellow
          say "  If you use importmap-rails, add these lines to your application.js:", :yellow
          say "    import \"trix\"", :cyan
          say "    import \"@rails/actiontext\"", :cyan
          return
        end

        contents = File.read(app_js)
        if contents.include?('import "trix"') || contents.include?("import 'trix'")
          say "application.js already imports trix — skipping.", :cyan
          return
        end

        say "Adding trix + @rails/actiontext imports to app/javascript/application.js", :green
        append_to_file app_js, <<~JS

          // Lean CMS uses Trix in the field-editor modal for rich_text fields.
          import "trix"
          import "@rails/actiontext"
        JS
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
        say ""
        say "       # Optional, but the admin nicely uses them when present:"
        say "       has_many :notifications, as: :recipient, dependent: :destroy,"
        say "                class_name: \"Noticed::Notification\""
        say "       def display_name;        name.presence || email_address.split(\"@\").first; end"
        say "       def permissions_summary"
        say "         return \"Super Admin\" if is_super_admin?"
        say "         perms = []"
        say "         perms << \"Pages\"    if can_edit_pages"
        say "         perms << \"Blog\"     if can_edit_blog"
        say "         perms << \"Users\"    if can_manage_users"
        say "         perms << \"Settings\" if can_access_settings"
        say "         perms.empty? ? \"No permissions\" : perms.join(\", \")"
        say "       end"
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
        say "   end"
        say ""
        say "   (Pundit is included automatically by the gem's admin controllers."
        say "   Add `include Pundit::Authorization` to your own ApplicationController"
        say "   only if you want `authorize` / `policy_scope` available in your"
        say "   non-CMS controllers too.)"
        say ""
        say "4. Include the helper in ApplicationHelper", :yellow
        say "   module ApplicationHelper"
        say "     include LeanCms::PageContentHelper"
        say "   end"
        say ""
        say "5. Add the admin bar to your public layout (optional but recommended)", :yellow
        say "   In app/views/layouts/application.html.erb:"
        say ""
        say "     <body class=\"<%= 'pt-10' if current_user&.has_any_cms_permission? %>\">"
        say "       <%= cms_admin_bar %>"
        say "       <!-- your header / content -->"
        say "     </body>"
        say ""
        say "   Gives signed-in editors a fixed strip with Inline Editing toggle,"
        say "   Help, Admin Dashboard, and Sign Out. Renders nothing for public visitors."
        say ""
        say "6. Seed your site structure", :yellow
        say "   Edit config/lean_cms_structure.yml, then:"
        say "     bin/rails lean_cms:load_structure"
        say ""
        say "7. Create your first admin", :yellow
        say "   bin/rails runner 'User.create!(email_address: \"admin@example.com\", password: \"change-me\", name: \"Admin\", active: true, is_super_admin: true)'"
        say ""
        say "8. Start the server and log in", :yellow
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
