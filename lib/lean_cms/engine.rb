module LeanCms
  class Engine < ::Rails::Engine
    # Note: isolate_namespace is intentionally omitted so that all lean_cms_* route
    # helpers remain accessible in both the engine and host app without renaming views.

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot
      g.factory_bot dir: "spec/factories"
    end

    # Add gem's JS to Propshaft's load path so Stimulus controllers can be served.
    # CSS (app/assets/lean_cms/) is discovered automatically via app/assets registration.
    initializer "lean_cms.assets" do |app|
      app.config.assets.paths << root.join("app/javascript")
    end

    # Register the gem's Stimulus controllers with the host app's importmap
    initializer "lean_cms.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join("config/importmap.rb")
      end
    end

    # Make the gem's migrations available to the host app
    initializer "lean_cms.migrations" do |app|
      unless app.root.to_s == root.to_s
        config.paths["db/migrate"].expanded.each do |path|
          app.config.paths["db/migrate"] << path
        end
      end
    end

    # Auto-generate the lean_cms.css Tailwind entry point in the host app on boot.
    # In production this file is created by the Dockerfile before asset precompile;
    # in development we create it here so `bin/dev` works without any manual step.
    initializer "lean_cms.tailwind_css" do |app|
      tailwind_dir = app.root.join("app/assets/builds/tailwind")
      lean_cms_css = tailwind_dir.join("lean_cms.css")
      unless lean_cms_css.exist?
        require "fileutils"
        FileUtils.mkdir_p(tailwind_dir)
        engine_css = root.join("app/assets/tailwind/lean_cms/engine.css")
        File.write(lean_cms_css, "@import \"#{engine_css}\";\n")
      end
    end

    # Ensure host app always has a resolvable edit-controls stylesheet path.
    # Place it under app/assets/stylesheets so stylesheet logical path resolution
    # matches `stylesheet_link_tag "lean_cms/cms_edit_controls"`.
    initializer "lean_cms.edit_controls_css" do |app|
      host_css = app.root.join("app/assets/stylesheets/lean_cms/cms_edit_controls.css")
      next if host_css.exist?

      require "fileutils"
      source_css = root.join("app/assets/lean_cms/cms_edit_controls.css")
      next unless source_css.exist?

      FileUtils.mkdir_p(host_css.dirname)
      File.write(host_css, source_css.read)
    end

    # Load rake tasks
    rake_tasks do
      load LeanCms::Engine.root.join("lib/tasks/lean_cms.rake")
    end
  end
end
