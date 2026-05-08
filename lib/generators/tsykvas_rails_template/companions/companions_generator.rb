# frozen_string_literal: true

require "rails/generators/base"
require "tsykvas_rails_template/probe"

module TsykvasRailsTemplate
  module Generators
    # Adds the recommended companion gems used across the author's reference
    # projects (sport / planner / esl). Runs `bundle install` and the per-gem
    # `:install` sub-generators (no User model is generated for Devise).
    #
    # Designed to be idempotent: re-running the generator does not duplicate
    # Gemfile entries, re-run sub-generators, or re-inject configuration.
    class CompanionsGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc <<~DESC
        Add and install the recommended companion gems for tsykvas_rails_template.

        Default groups: auth (devise + omniauth-csrf), forms (simple_form),
        images (mini_magick), jobs-ui (mission_control-jobs, only if solid_queue),
        test (rspec-rails + factory_bot_rails + shoulda-matchers + webmock + faker),
        dev (dotenv-rails). Use --skip-* flags to opt out per group.

        Devise's User model is NOT generated — run `rails g devise User` (or
        whatever resource name fits your domain) yourself when ready.
      DESC

      class_option :skip_auth,
                   type: :boolean, default: false,
                   desc: "Don't add devise + omniauth-rails_csrf_protection"
      class_option :skip_forms,
                   type: :boolean, default: false,
                   desc: "Don't add simple_form"
      class_option :skip_images,
                   type: :boolean, default: false,
                   desc: "Don't add mini_magick"
      class_option :skip_jobs_ui,
                   type: :boolean, default: false,
                   desc: "Don't add mission_control-jobs (or its mount)"
      class_option :skip_test,
                   type: :boolean, default: false,
                   desc: "Don't add the rspec/factory_bot/shoulda/webmock/faker stack"
      class_option :skip_dev,
                   type: :boolean, default: false,
                   desc: "Don't add dotenv-rails"
      class_option :skip_bundle,
                   type: :boolean, default: false,
                   desc: "Don't run `bundle install` after editing Gemfile"
      class_option :skip_post_install,
                   type: :boolean, default: false,
                   desc: "Don't run `:install` sub-generators or inject configs"

      def add_top_level_gems
        wanted = []
        wanted += %w[devise omniauth-rails_csrf_protection] unless options[:skip_auth]
        wanted << "simple_form" unless options[:skip_forms]
        wanted << "mini_magick" unless options[:skip_images]
        wanted << "mission_control-jobs" if !options[:skip_jobs_ui] && solid_queue_present?

        wanted.each { |name| add_gem_if_missing(name) }
      end

      def add_test_group_gems
        return if options[:skip_test]

        add_grouped_gems(%i[development test], %w[rspec-rails factory_bot_rails faker])
        add_grouped_gems([:test], %w[shoulda-matchers webmock])
      end

      def add_dev_group_gems
        return if options[:skip_dev]

        add_grouped_gems(%i[development test], %w[dotenv-rails])
      end

      def run_bundle_install
        return if options[:skip_bundle]

        in_root do
          Bundler.with_unbundled_env do
            run "bundle install"
          end
        end
      end

      # Bump the companion gems we just added to their latest matching
      # versions. `bundle install` is a no-op on re-runs where Gemfile.lock
      # already pins older versions; `bundle update` lifts those pins within
      # whatever constraint the Gemfile expresses (none, by default → latest).
      def bundle_update_companions
        return if options[:skip_bundle]

        names = companion_gem_names
        return if names.empty?

        in_root do
          Bundler.with_unbundled_env { run "bundle update #{names.join(" ")}" }
        end
      end

      def run_devise_install
        return if skip_post_install_for?(:auth)
        return if File.exist?(destination_path("config/initializers/devise.rb"))

        generate "devise:install"
      end

      def run_simple_form_install
        return if skip_post_install_for?(:forms)
        return if File.exist?(destination_path("config/initializers/simple_form.rb"))

        flag = probe[:has_bootstrap] ? " --bootstrap" : ""
        generate "simple_form:install#{flag}"
      end

      def run_rspec_install
        return if skip_post_install_for?(:test)
        return if File.exist?(destination_path("spec/rails_helper.rb"))

        generate "rspec:install"
      end

      def configure_shoulda_matchers
        return if skip_post_install_for?(:test)
        return unless File.exist?(destination_path("spec/rails_helper.rb"))
        return if File.read(destination_path("spec/rails_helper.rb")).include?("Shoulda::Matchers")

        append_to_file "spec/rails_helper.rb", shoulda_config_block
      end

      def configure_webmock
        return if skip_post_install_for?(:test)
        return unless File.exist?(destination_path("spec/rails_helper.rb"))
        return if File.read(destination_path("spec/rails_helper.rb")).include?("WebMock.disable_net_connect!")

        append_to_file "spec/rails_helper.rb", webmock_config_block
      end

      def mount_mission_control_jobs
        return if skip_post_install_for?(:jobs_ui)
        return unless solid_queue_present?
        return unless File.exist?(destination_path("config/routes.rb"))
        return if File.read(destination_path("config/routes.rb")).include?("MissionControl::Jobs::Engine")

        route mission_control_route_block
      end

      def add_dotenv_to_gitignore
        return if skip_post_install_for?(:dev)
        return unless File.exist?(destination_path(".gitignore"))
        return if File.read(destination_path(".gitignore")).match?(/^\.env\b/)

        append_to_file ".gitignore",
                       "\n# dotenv-rails (added by tsykvas_rails_template:companions)\n.env\n.env.*\n!.env.example\n"
      end

      def announce
        say ""
        say "  Companions installed.", :green
        say "    Next: rails g devise User  (run yourself when your user schema is ready)"
        say "    /jobs UI is mounted with admin-only constraint; needs User#admin?"
        say "    Image processing requires ImageMagick installed system-wide."
        say ""
      end

      private

      def destination_path(rel)
        File.join(destination_root, rel)
      end

      def gemfile_path
        destination_path("Gemfile")
      end

      def gemfile_content
        @gemfile_content = nil if defined?(@gemfile_content_mtime) && @gemfile_content_mtime != File.mtime(gemfile_path)
        return "" unless File.exist?(gemfile_path)

        @gemfile_content_mtime = File.mtime(gemfile_path)
        @gemfile_content ||= File.read(gemfile_path)
      end

      def gem_in_gemfile?(name)
        gemfile_content.match?(/^\s*gem\s+['"]#{Regexp.escape(name)}['"]/)
      end

      def add_gem_if_missing(name, *args)
        if gem_in_gemfile?(name)
          say_status :exist, "gem '#{name}' already in Gemfile", :blue
          return
        end

        gem(name, *args)
        # Force re-read on next gem_in_gemfile? check.
        @gemfile_content = nil
      end

      def add_grouped_gems(groups, names)
        needed = names.reject { |n| gem_in_gemfile?(n) }
        return if needed.empty?

        gem_group(*groups) { needed.each { |n| gem n } }
        @gemfile_content = nil
      end

      COMPANION_GROUPS = {
        skip_auth: %w[devise omniauth-rails_csrf_protection],
        skip_forms: %w[simple_form],
        skip_images: %w[mini_magick],
        skip_test: %w[rspec-rails factory_bot_rails faker shoulda-matchers webmock],
        skip_dev: %w[dotenv-rails]
      }.freeze

      def companion_gem_names
        names = COMPANION_GROUPS.flat_map { |opt, gems| options[opt] ? [] : gems }
        names << "mission_control-jobs" if !options[:skip_jobs_ui] && solid_queue_present?
        names.select { |n| gem_in_gemfile?(n) }
      end

      def probe
        @probe ||= TsykvasRailsTemplate::Probe.run(root: destination_root)
      end

      def solid_queue_present?
        probe[:background_jobs].include?(:solid_queue)
      end

      def skip_post_install_for?(group)
        return true if options[:skip_post_install]

        options["skip_#{group}".to_sym]
      end

      def shoulda_config_block
        <<~RUBY

          # shoulda-matchers (added by tsykvas_rails_template:companions)
          Shoulda::Matchers.configure do |config|
            config.integrate do |with|
              with.test_framework :rspec
              with.library :rails
            end
          end
        RUBY
      end

      def webmock_config_block
        <<~RUBY

          # webmock (added by tsykvas_rails_template:companions)
          require "webmock/rspec"
          WebMock.disable_net_connect!(allow_localhost: true)
        RUBY
      end

      def mission_control_route_block
        <<~RUBY
          # MissionControl::Jobs UI — admins only.
          # Lambda runs per request, so missing User model at boot doesn't crash.
          # Without User#admin? all /jobs requests return 404 (lock-by-default).
          mount MissionControl::Jobs::Engine,
                at: "/jobs",
                constraints: ->(req) {
                  user = req.env["warden"]&.user
                  user.respond_to?(:admin?) && user.admin?
                }
        RUBY
      end
    end
  end
end
