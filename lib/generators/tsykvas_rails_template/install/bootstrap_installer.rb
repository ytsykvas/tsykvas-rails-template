# frozen_string_literal: true

module TsykvasRailsTemplate
  module Generators
    # Bootstrap install steps for InstallGenerator. Lives in its own module so
    # the generator stays under the class-length limit and the Bootstrap-only
    # logic is grouped together for opt-out (`--skip-bootstrap`).
    #
    # Expects the host to provide: `say_status`, `gem`, `create_file`,
    # `empty_directory`, `append_to_file`, `in_root`, `destination_root`, `run`.
    # All of those are Thor::Group / Rails::Generators::Base helpers.
    module BootstrapInstaller
      BOOTSTRAP_SCSS_ENTRY_PATH = "app/assets/stylesheets/application.bootstrap.scss"
      BOOTSTRAP_SCSS_ENTRY_BODY = <<~SCSS
        // tsykvas_rails_template — Bootstrap entrypoint compiled by dartsass-rails
        // into app/assets/builds/application.css. Override $variables above the
        // import to theme; add component partials below.
        @import "bootstrap";
      SCSS

      DARTSASS_INITIALIZER_PATH = "config/initializers/dartsass.rb"
      # `build_options` is consumed by dartsass-rails as Array#flat_map(&:split),
      # so it MUST be an Array (a String would NoMethodError at build time).
      # We extend dartsass-rails' own defaults (compressed + no-source-map):
      #   --quiet-deps                   silences warnings from gem load paths
      #                                   (Bootstrap 5.3.x's internal noise:
      #                                   @import / red() / mix() — 311 warns)
      #   --silence-deprecation=import   silences the lone warning on the
      #                                   `@import "bootstrap"` in our own
      #                                   application.bootstrap.scss
      #                                   (Bootstrap 5.3 has no @use replacement)
      DARTSASS_MANAGED_HEADER = "# Managed by tsykvas_rails_template:install — re-running install rewrites this file."
      DARTSASS_INITIALIZER_BODY = <<~RUBY.freeze
        # frozen_string_literal: true
        #{DARTSASS_MANAGED_HEADER}

        # tsykvas_rails_template — dartsass-rails build map.
        # Keys are sources under app/assets/stylesheets, values are outputs
        # under app/assets/builds (which Propshaft serves).
        Rails.application.config.dartsass.builds = {
          "application.bootstrap.scss" => "application.css"
        }

        Rails.application.config.dartsass.build_options = [
          "--style=compressed",
          "--no-source-map",
          "--quiet-deps",
          "--silence-deprecation=import"
        ]
      RUBY

      IMPORTMAP_PINS = <<~RUBY
        pin "bootstrap", to: "https://ga.jspm.io/npm:bootstrap@5.3.3/dist/js/bootstrap.esm.js", preload: true
        pin "@popperjs/core", to: "https://ga.jspm.io/npm:@popperjs/core@2.11.8/lib/index.js", preload: true
      RUBY

      APPLICATION_JS_PATH = "app/javascript/application.js"
      APPLICATION_JS_BOOTSTRAP_BLOCK = <<~JS

        // Bootstrap (added by tsykvas_rails_template:install) — exposed globally
        // so OperationsMethods' format.js modal-dismiss path can call it.
        import * as bootstrap from "bootstrap"
        window.bootstrap = bootstrap
      JS

      PROCFILE_DEV_PATH = "Procfile.dev"
      PROCFILE_DEV_BODY = <<~PROC
        web: bin/rails server
        css: bin/rails dartsass:watch
      PROC

      private

      def install_bootstrap_steps
        add_bootstrap_gems
        run_bundle_install_for_bootstrap
        bundle_update_bootstrap_gems
        write_bootstrap_scss_entry
        ensure_assets_builds_directory
        write_dartsass_initializer
        pin_bootstrap_via_importmap
        wire_application_js_bootstrap_import
        write_procfile_dev
        ensure_foreman_installed
        precompile_bootstrap_css
      end

      def add_bootstrap_gems
        add_gem_if_missing("bootstrap", "~> 5.3")
        add_gem_if_missing("dartsass-rails")
      end

      def gemfile_includes?(name)
        gemfile = destination_path("Gemfile")
        return false unless File.exist?(gemfile)

        File.read(gemfile).match?(/^\s*gem\s+['"]#{Regexp.escape(name)}['"]/)
      end

      def add_gem_if_missing(name, *args)
        if gemfile_includes?(name)
          say_status :exist, "gem '#{name}' already in Gemfile", :blue
          return
        end

        gem(name, *args)
      end

      def run_bundle_install_for_bootstrap
        in_root do
          Bundler.with_unbundled_env { run "bundle install" }
        end
      end

      # Re-runs of install on existing hosts may have older bootstrap /
      # dartsass-rails versions locked in Gemfile.lock. `bundle install` is a
      # no-op there. `bundle update` bumps to the latest within the Gemfile
      # constraints (e.g. latest 5.3.x for `~> 5.3`).
      def bundle_update_bootstrap_gems
        in_root do
          Bundler.with_unbundled_env { run "bundle update bootstrap dartsass-rails" }
        end
      end

      def write_bootstrap_scss_entry
        path = destination_path(BOOTSTRAP_SCSS_ENTRY_PATH)
        if File.exist?(path)
          say_status :exist, BOOTSTRAP_SCSS_ENTRY_PATH, :blue
          return
        end

        empty_directory File.dirname(BOOTSTRAP_SCSS_ENTRY_PATH) unless File.directory?(File.dirname(path))
        create_file BOOTSTRAP_SCSS_ENTRY_PATH, BOOTSTRAP_SCSS_ENTRY_BODY
      end

      def ensure_assets_builds_directory
        keep = "app/assets/builds/.keep"
        return if File.exist?(destination_path(keep))

        empty_directory "app/assets/builds" unless File.directory?(destination_path("app/assets/builds"))
        create_file keep, ""
      end

      def write_dartsass_initializer
        path = destination_path(DARTSASS_INITIALIZER_PATH)
        unless File.exist?(path)
          create_file DARTSASS_INITIALIZER_PATH, DARTSASS_INITIALIZER_BODY
          return
        end

        contents = File.read(path)
        if contents == DARTSASS_INITIALIZER_BODY
          say_status :exist, DARTSASS_INITIALIZER_PATH, :blue
          return
        end

        # Re-running install rewrites the initializer to its canonical form.
        # The "managed" header marks this file as gem-owned so users know edits
        # don't survive — customise dartsass options elsewhere if you need to.
        File.write(path, DARTSASS_INITIALIZER_BODY)
        if contents.include?(DARTSASS_MANAGED_HEADER)
          say_status :update, "#{DARTSASS_INITIALIZER_PATH} (managed)", :green
        else
          say_status :overwrite,
                     "#{DARTSASS_INITIALIZER_PATH} (was hand-edited; superseded by canonical form)",
                     :yellow
        end
      end

      def pin_bootstrap_via_importmap
        importmap = destination_path("config/importmap.rb")
        return unless File.exist?(importmap)
        return if File.read(importmap).include?(%(pin "bootstrap"))

        append_to_file "config/importmap.rb",
                       "\n# Bootstrap (added by tsykvas_rails_template:install)\n#{IMPORTMAP_PINS}"
      end

      def wire_application_js_bootstrap_import
        path = destination_path(APPLICATION_JS_PATH)
        return unless File.exist?(path)
        return if File.read(path).include?('import * as bootstrap from "bootstrap"')

        append_to_file APPLICATION_JS_PATH, APPLICATION_JS_BOOTSTRAP_BLOCK
      end

      def write_procfile_dev
        path = destination_path(PROCFILE_DEV_PATH)
        if File.exist?(path)
          return if File.read(path).include?("dartsass:watch")

          append_to_file PROCFILE_DEV_PATH, "css: bin/rails dartsass:watch\n"
        else
          create_file PROCFILE_DEV_PATH, PROCFILE_DEV_BODY
        end
      end

      def precompile_bootstrap_css
        in_root do
          Bundler.with_unbundled_env { run "bin/rails dartsass:build" }
        end
      end

      # Foreman is required for `bin/dev` (which reads Procfile.dev) but its
      # README explicitly says don't add it to Gemfile — install it system-wide.
      # Idempotent: skip when already on PATH.
      def ensure_foreman_installed
        if foreman_already_installed?
          say_status :exist, "foreman already installed system-wide", :blue
          return
        end

        in_root do
          Bundler.with_unbundled_env { run "gem install foreman --no-document" }
        end
      end

      def foreman_already_installed?
        Bundler.with_unbundled_env do
          system("gem list -i foreman > /dev/null 2>&1")
        end
      end
    end
  end
end
