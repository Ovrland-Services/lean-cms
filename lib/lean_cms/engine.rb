module LeanCms
  class Engine < ::Rails::Engine
    # Note: isolate_namespace is intentionally omitted so that all lean_cms_* route
    # helpers remain accessible in both the engine and host app without renaming views.

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot
      g.factory_bot dir: "spec/factories"
    end

    # Add gem's JS to Propshaft's asset load path so files can be served
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

    # Load rake tasks
    rake_tasks do
      load LeanCms::Engine.root.join("lib/tasks/lean_cms.rake")

      # Ensure app/assets/builds/tailwind/lean_cms.css exists before tailwindcss:build
      # compiles application.css. tailwindcss-rails v4 calls tailwindcss:engines first,
      # which calls Engines.bundle — but if the engine isn't auto-detected (e.g. on a
      # fresh bundle), we create the file explicitly as a fallback.
      if Rake::Task.task_defined?("tailwindcss:engines")
        Rake::Task["tailwindcss:engines"].enhance do
          builds_dir = Rails.root.join("app/assets/builds/tailwind")
          output = builds_dir.join("lean_cms.css")
          next if output.exist?

          FileUtils.mkdir_p(builds_dir)
          engine_css = LeanCms::Engine.root.join("app/assets/tailwind/lean_cms/engine.css")
          File.write(output,
            engine_css.exist? ? "@import \"#{engine_css}\";\n" : "/* lean_cms: engine.css not found */\n"
          )
        end
      end
    end
  end
end
