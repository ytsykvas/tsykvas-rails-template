# frozen_string_literal: true

require "pathname"
require "yaml"

module TsykvasRailsTemplate
  # Deterministic project inventory for `/tsykvas-claude`.
  #
  # Reads files from a Rails app root and returns a structured Hash that the
  # slash command can consume verbatim — keeps the LLM out of the inventory
  # step so what's "true about the project" is testable and stable run-to-run.
  class Probe
    SCHEMA_VERSION = 2

    def self.run(root: Dir.pwd)
      new(root).run
    end

    def initialize(root)
      @root = Pathname(root)
    end

    def run
      {
        schema_version: SCHEMA_VERSION,
        gem_version: TsykvasRailsTemplate::VERSION,
        root: root.to_s,
        ruby_version: detect_ruby_version,
        rails_version: detect_rails_version,
        default_branch: detect_default_branch,
        api_only: detect_api_only,
        engine_host: detect_engine_host,
        template_engine: detect_template_engine,
        auth: detect_auth,
        authorization: detect_authorization,
        has_api_v1: detect_api_v1,
        has_bootstrap: detect_bootstrap,
        test_framework: detect_test_framework,
        background_jobs: detect_background_jobs,
        databases: detect_databases,
        concept_folders: detect_concept_folders,
        application_controller_includes: detect_application_controller_includes
      }
    end

    private

    attr_reader :root

    def gemfile_lock
      @gemfile_lock ||= read("Gemfile.lock").to_s
    end

    def routes_rb
      @routes_rb ||= read("config/routes.rb").to_s
    end

    def application_rb
      @application_rb ||= read("config/application.rb").to_s
    end

    def application_controller_rb
      @application_controller_rb ||= read("app/controllers/application_controller.rb").to_s
    end

    def detect_ruby_version
      ruby_file = read(".ruby-version")
      return ruby_file.strip.sub(/^ruby[ \t-]+/, "") if ruby_file

      gemfile_lock[/RUBY VERSION\s+ruby (\S+)/, 1]
    end

    def detect_rails_version
      gemfile_lock[/^\s+rails \((\S+)\)/, 1]
    end

    def detect_default_branch
      head = read(".git/HEAD")
      return head[%r{ref: refs/heads/(\S+)}, 1] if head

      nil
    end

    # config.api_only = true → host is API-only (no template engine, no AssetPipeline)
    def detect_api_only
      application_rb.match?(/config\.api_only\s*=\s*true/)
    end

    # `class XxxApplication < Rails::Engine` instead of `< Rails::Application` → host is an engine
    def detect_engine_host
      application_rb.match?(/<\s*Rails::Engine\b/)
    end

    def detect_template_engine
      return nil if detect_api_only
      return :slim if gem?("slim-rails") || gem?("slim")
      return :haml if gem?("haml-rails") || gem?("haml")

      :erb
    end

    # Returns a structured Hash with detected auth signals.
    #
    # `method` is a coarse classification: :devise, :devise_omniauth, :custom,
    # :basic_auth, :jwt, :warden, or :none. Multiple flags can be true.
    def detect_auth
      flags = auth_flags
      flags[:method] = classify_auth_method(flags)
      flags
    end

    AUTH_METHOD_PRIORITY = %i[devise warden jwt basic_auth custom_current_user].freeze
    private_constant :AUTH_METHOD_PRIORITY

    def auth_flags
      ac = application_controller_rb
      {
        devise: gem?("devise"),
        omniauth: gem?("omniauth"),
        omniauth_openid_connect: gem?("omniauth_openid_connect"),
        warden: gem?("warden") || ac.include?("Warden::"),
        jwt: gem?("jwt") || ac.include?("JsonWebToken") || ac.include?("decode_jwt"),
        basic_auth: ac.include?("authenticate_or_request_with_http_basic"),
        custom_current_user: ac.match?(/^\s*def\s+current_user\b/) ||
          ac.match?(/helper_method\s+.*:current_user/)
      }
    end

    def classify_auth_method(flags)
      return :devise_omniauth if flags[:devise] && flags[:omniauth_openid_connect]

      hit = AUTH_METHOD_PRIORITY.find { |key| flags[key] }
      return :none unless hit

      hit == :custom_current_user ? :custom : hit
    end

    def detect_authorization
      return :pundit if gem?("pundit")
      return :action_policy if gem?("action_policy")
      return :cancancan if gem?("cancancan") || gem?("cancan")

      :none
    end

    def detect_api_v1
      return true if routes_rb.match?(/namespace\s+:api\b/) &&
                     routes_rb.match?(/namespace\s+:v1\b/)
      return true if routes_rb.match?(%r{["']/?api/v1["']})

      Dir.glob(root.join("app/controllers/api/v1/**/*.rb").to_s).any?
    end

    def detect_bootstrap
      return true if gem?("bootstrap") || gem?("bootstrap-rubygem")
      return true if file_contains?("config/importmap.rb", /bootstrap/i)

      file_contains?("package.json", /"bootstrap"\s*:/)
    end

    def detect_test_framework
      return :rspec if gem?("rspec-rails") || gem?("rspec")

      :minitest
    end

    def detect_background_jobs
      [
        (:solid_queue if gem?("solid_queue")),
        (:sidekiq if gem?("sidekiq")),
        (:good_job if gem?("good_job")),
        (:delayed_job if gem?("delayed_job")),
        (:resque if gem?("resque")),
        (:que if gem?("que"))
      ].compact
    end

    # Detect databases from config/database.yml top-level keys (multi-DB-aware).
    # Returns a list of names like ["primary", "queue", "cache", "cable"]; falls
    # back to ["primary"] when only the legacy single-DB shape is present.
    def detect_databases
      raw = read("config/database.yml")
      return [] unless raw

      parsed = safe_yaml(raw)
      return [] unless parsed.is_a?(Hash)

      env = parsed["development"] || parsed[parsed.keys.first]
      return ["primary"] unless env.is_a?(Hash)

      keys = env.keys
      keys.all? { |k| env[k].is_a?(Hash) } ? keys.sort : ["primary"]
    end

    def detect_concept_folders
      base = root.join("app/concepts")
      return [] unless base.directory?

      base.children
          .select(&:directory?)
          .map { |p| p.basename.to_s }
          .reject { |n| n == "base" }
          .sort
    end

    def detect_application_controller_includes
      application_controller_rb.scan(/^\s*include\s+([\w:]+)/).flatten
    end

    def gem?(name)
      gemfile_lock.match?(/^\s+#{Regexp.escape(name)} \(/)
    end

    def file_contains?(rel, pattern)
      contents = read(rel)
      !!contents && contents.match?(pattern)
    end

    def read(rel)
      path = root.join(rel)
      return nil unless path.file?

      path.read
    rescue Errno::ENOENT
      nil
    end

    def safe_yaml(raw)
      # Strip ERB so YAML.safe_load doesn't choke on `<%= ENV[...] %>` etc.
      stripped = raw.gsub(/<%=?.*?%>/m, "''")
      YAML.safe_load(stripped, aliases: true) || {}
    rescue Psych::SyntaxError, ArgumentError
      {}
    end
  end
end
