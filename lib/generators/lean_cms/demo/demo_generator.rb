require "rails/generators"

module LeanCms
  module Generators
    class DemoGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs Lean CMS demo pages: Home, About, and Contact with all 9 content types"

      def copy_pages_controller
        template "pages_controller.rb", "app/controllers/pages_controller.rb"
      end

      def copy_views
        directory "views/pages", "app/views/pages"
      end

      def copy_structure_yaml
        template "lean_cms_structure.yml", "config/lean_cms_structure.yml",
                 force: options[:force]
      end

      def add_routes
        route <<~RUBY
          get 'about',   to: 'pages#about',   as: :about
          get 'contact', to: 'pages#contact',  as: :contact
          post 'contact', to: 'pages#submit_contact'
          root 'pages#home'
        RUBY
      end

      def seed_content
        say "Seeding demo content...", :yellow
        rake "lean_cms:load_structure"
      rescue StandardError => e
        say "  Could not auto-seed (run 'rails lean_cms:load_structure' manually): #{e.message}", :yellow
      end

      def print_instructions
        say "\n#{"=" * 60}", :green
        say "Lean CMS demo pages installed!", :green
        say "=" * 60, :green
        say ""
        say "Demo pages:"
        say "  /           -> Home (hero, features cards, intro text)"
        say "  /about      -> About (rich text, image, bullets, boolean toggle)"
        say "  /contact    -> Contact (URL, color, dropdown, form)"
        say ""
        say "Log in at /lean-cms to see in-context editing in action."
        say ""
      end
    end
  end
end
