# frozen_string_literal: true

require "rails/generators/base"
require_relative "bootstrap_installer"

module TsykvasRailsTemplate
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      include BootstrapInstaller

      source_root File.expand_path("templates", __dir__)

      desc <<~DESC
        Install the tsykvas_rails_template skeleton:
          - copies app/concepts/base/{operation,component}/* into the host
          - copies the OperationsMethods controller concern (the `endpoint` DSL)
          - registers app/concepts in config.autoload_paths
          - wires Pundit::Authorization + OperationsMethods into ApplicationController
          - generates ApplicationPolicy if missing
          - scaffolds a Home example concept (controller + operation + component
            + HomePolicy + root route) showing the canonical one-liner pattern
          - drops .claude/{agents,commands,docs}/* and a CLAUDE.md scaffold
      DESC

      class_option :skip_application_policy,
                   type: :boolean,
                   default: false,
                   desc: "Don't generate ApplicationPolicy if it doesn't exist"

      class_option :skip_autoload_paths,
                   type: :boolean,
                   default: false,
                   desc: "Don't patch config/application.rb"

      class_option :skip_claude,
                   type: :boolean,
                   default: false,
                   desc: "Don't drop .claude/ payload or CLAUDE.md"

      class_option :skip_home_example,
                   type: :boolean,
                   default: false,
                   desc: "Don't scaffold the Home example concept + root route"

      class_option :keep_sqlite,
                   type: :boolean,
                   default: false,
                   desc: "Don't swap sqlite3 for pg in the Gemfile (default: always swap to PostgreSQL)"

      class_option :skip_bootstrap,
                   type: :boolean,
                   default: false,
                   desc: "Don't install bootstrap + dartsass-rails or wire the SCSS / importmap pins"

      def swap_database_to_postgresql
        return if options[:keep_sqlite]

        swap_gemfile_to_pg
        swap_database_yml_to_pg
      end

      def copy_concepts_base
        directory "app/concepts/base", "app/concepts/base"
      end

      def copy_operations_methods_concern
        copy_file "app/controllers/concerns/operations_methods.rb",
                  "app/controllers/concerns/operations_methods.rb"
      end

      def add_concepts_to_autoload_paths
        return if options[:skip_autoload_paths]

        target = destination_path("config/application.rb")
        return unless File.exist?(target)

        marker = "app/concepts"
        contents = File.read(target)
        if contents.include?("#{marker}]") || contents.include?("#{marker}\"]")
          say_status :exist, "config.autoload_paths already includes #{marker}", :blue
          return
        end

        application "config.autoload_paths += %W[\#{config.root}/app/concepts]\n"
      end

      def wire_application_controller
        target_rel = "app/controllers/application_controller.rb"
        target_abs = destination_path(target_rel)
        return unless File.exist?(target_abs)

        contents = File.read(target_abs)

        unless contents.include?("Pundit::Authorization") || contents.include?("include Pundit\n")
          inject_into_class target_rel, "ApplicationController", "  include Pundit::Authorization\n"
        end

        return if contents.include?("OperationsMethods")

        inject_into_class target_rel, "ApplicationController", "  include OperationsMethods\n"
      end

      def create_application_policy
        return if options[:skip_application_policy]
        return if File.exist?(destination_path("app/policies/application_policy.rb"))

        empty_directory "app/policies" unless File.directory?(destination_path("app/policies"))
        copy_file "app/policies/application_policy.rb",
                  "app/policies/application_policy.rb"
      end

      def generate_home_example
        return if options[:skip_home_example]
        return if File.exist?(destination_path("app/controllers/home_controller.rb"))
        return if File.directory?(destination_path("app/concepts/home"))

        copy_file "app/controllers/home_controller.rb",
                  "app/controllers/home_controller.rb"
        directory "app/concepts/home", "app/concepts/home"

        empty_directory "app/policies" unless File.directory?(destination_path("app/policies"))
        return if File.exist?(destination_path("app/policies/home_policy.rb"))

        copy_file "app/policies/home_policy.rb", "app/policies/home_policy.rb"
      end

      def add_root_route
        return if options[:skip_home_example]

        routes_path = destination_path("config/routes.rb")
        return unless File.exist?(routes_path)
        return if File.read(routes_path).match?(/^\s*root\s/)

        route 'root "home#index"'
      end

      def install_bootstrap
        return if options[:skip_bootstrap]

        install_bootstrap_steps

        say_status :bootstrap,
                   "Bootstrap 5.3 + dartsass-rails wired. Run `bin/dev` for the live SCSS watcher, " \
                   "or `bin/rails dartsass:build` once before `bin/rails server`. " \
                   "Pass --skip-bootstrap to opt out.",
                   :green
      end

      # Propshaft serves from `public/assets/` whenever a `.manifest.json` is
      # there, completely bypassing live `app/assets/builds/` and
      # `app/javascript/`. A stale dir from a prior `rails assets:precompile`
      # silently freezes the dev environment. Clean it here — but only if
      # `.gitignore` lists it (so we know it's a transient cache, not
      # checked-in content). `rails new` adds `/public/assets` by default.
      def clean_propshaft_cache
        require "fileutils"

        cache_dir = destination_path("public/assets")
        return unless File.directory?(cache_dir)

        gitignore = destination_path(".gitignore")
        listed = File.exist?(gitignore) && File.read(gitignore).match?(%r{^/?public/assets\b})
        unless listed
          say_status :skip,
                     "public/assets/ exists but is not in .gitignore — leaving alone " \
                     "(it might be checked-in content rather than a Propshaft cache).",
                     :yellow
          return
        end

        FileUtils.rm_rf(cache_dir)
        say_status :clean,
                   "Removed stale public/assets/ (Propshaft would otherwise shadow live " \
                   "app/assets/builds/ and app/javascript/ in dev).",
                   :green
      end

      SHIPPED_DOCS = %w[
        architecture
        authentication
        background-jobs
        code-style
        commands
        companions
        concepts-refactoring
        database
        deployment
        design-system
        documentation
        forms
        i18n
        routing-and-namespaces
        security
        stimulus-controllers
        testing
        testing-examples
        tsykvas_rails_template
        ui-components
      ].freeze

      def copy_claude_payload
        return if options[:skip_claude]

        directory ".claude/agents", ".claude/agents"
        directory ".claude/commands", ".claude/commands"
        empty_directory ".claude/docs" unless File.directory?(destination_path(".claude/docs"))
        SHIPPED_DOCS.each do |name|
          copy_file ".claude/docs/#{name}.md", ".claude/docs/#{name}.md"
        end
      end

      def write_claude_md
        return if options[:skip_claude]

        if File.exist?(destination_path("CLAUDE.md"))
          say_status :skip,
                     "CLAUDE.md already exists; not overwriting. " \
                     "Run `/tsykvas-claude` in Claude Code to integrate the gem's " \
                     "must-know-rules and routing table inside fence markers without " \
                     "touching your existing content.",
                     :yellow
          return
        end

        template "CLAUDE.md.tt", "CLAUDE.md"
      end

      def announce_completion
        say ""
        say "  tsykvas_rails_template installed.", :green
        say "    A working Home example landed at /app/concepts/home/ with"
        say "    `root \"home#index\"` already in routes — start `bin/rails server`"
        say "    and visit http://localhost:3000 to see it (unless you passed"
        say "    --skip-home-example)."
        say ""
        say "    Next steps:"
        say "      1. rails g tsykvas_rails_template:companions"
        say "         (adds devise / simple_form / rspec stack / mini_magick / etc."
        say "          and runs their :install sub-generators)"
        say "      2. rails g tsykvas_rails_template:concept <Name> [--controller]"
        say "         scaffolds your domain concepts."
        say "      3. Open Claude Code and run /tsykvas-claude to refresh"
        say "         probe-driven sections in CLAUDE.md + .claude/docs/"
        say "         (concept folders, gem versions, branch names) when"
        say "         your stack changes."
        say ""
      end

      private

      def destination_path(rel)
        File.join(destination_root, rel)
      end

      def swap_gemfile_to_pg
        gemfile = destination_path("Gemfile")
        return unless File.exist?(gemfile)

        contents = File.read(gemfile)
        return if contents.match?(/^\s*gem\s+['"]pg['"]/)

        if contents.match?(/^\s*gem\s+['"]sqlite3['"]/)
          gsub_file "Gemfile",
                    /^(\s*)gem\s+['"]sqlite3['"][^\n]*$/,
                    "\\1# gem \"sqlite3\" — replaced by tsykvas_rails_template:install\n\\1gem \"pg\""
        else
          append_to_file "Gemfile", %(\ngem "pg"\n)
        end
      end

      def swap_database_yml_to_pg
        yml_path = destination_path("config/database.yml")
        return unless File.exist?(yml_path)

        contents = File.read(yml_path)
        return unless contents.match?(/adapter:\s*sqlite3/)

        # adapter: sqlite3 → adapter: postgresql (+ encoding: unicode)
        gsub_file "config/database.yml",
                  /^(\s*)adapter:\s*sqlite3\s*$/,
                  "\\1adapter: postgresql\n\\1encoding: unicode"
        # Drop sqlite-only `timeout:` lines.
        gsub_file "config/database.yml", /^\s*timeout:\s*\d+\s*\n/, ""
        # storage/<env>.sqlite3 → <app_name>_<env>
        app = File.basename(destination_root).tr("-", "_")
        gsub_file "config/database.yml",
                  %r{database:\s*storage/(\w+)\.sqlite3},
                  "database: #{app}_\\1"

        say_status :db,
                   "Swapped sqlite3 → pg in Gemfile + config/database.yml. " \
                   "Run `bundle install && bin/rails db:create` after install completes. " \
                   "Pass --keep-sqlite to skip the swap.",
                   :yellow
      end
    end
  end
end
