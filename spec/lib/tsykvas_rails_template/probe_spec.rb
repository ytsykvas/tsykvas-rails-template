# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "tsykvas_rails_template/probe"

RSpec.describe TsykvasRailsTemplate::Probe do
  FIXTURE_ROOT = File.expand_path("../../fixtures/dummy_app", __dir__) # rubocop:disable Lint/ConstantDefinitionInBlock

  def with_dummy_app(&block)
    tmp = Dir.mktmpdir("tsykvas-probe-spec-")
    FileUtils.cp_r("#{FIXTURE_ROOT}/.", tmp)
    FileUtils.mkdir_p("#{tmp}/.git")
    File.write("#{tmp}/.git/HEAD", "ref: refs/heads/main\n")
    block.call(tmp)
  ensure
    FileUtils.remove_entry(tmp) if tmp && Dir.exist?(tmp)
  end

  describe ".run on a representative dummy app" do
    let(:project_root) do
      tmp = Dir.mktmpdir("tsykvas-probe-spec-")
      FileUtils.cp_r("#{FIXTURE_ROOT}/.", tmp)
      FileUtils.mkdir_p("#{tmp}/.git")
      File.write("#{tmp}/.git/HEAD", "ref: refs/heads/main\n")
      tmp
    end

    after { FileUtils.remove_entry(project_root) if Dir.exist?(project_root) }

    let(:result) { described_class.run(root: project_root) }

    it "stamps schema 2 (multi-DB + api_only + engine_host fields)" do
      expect(result[:schema_version]).to eq(2)
      expect(described_class::SCHEMA_VERSION).to eq(2)
    end

    it "stamps the gem version" do
      expect(result[:gem_version]).to eq(TsykvasRailsTemplate::VERSION)
    end

    it "returns the project root that was probed" do
      expect(result[:root]).to eq(project_root)
    end

    it "detects Ruby version from .ruby-version" do
      expect(result[:ruby_version]).to eq("3.4.7")
    end

    it "detects Rails version from Gemfile.lock" do
      expect(result[:rails_version]).to eq("8.0.2")
    end

    it "reads the default branch from .git/HEAD" do
      expect(result[:default_branch]).to eq("main")
    end

    it "detects Slim as the template engine" do
      expect(result[:template_engine]).to eq(:slim)
    end

    it "detects Pundit as the authorization stack" do
      expect(result[:authorization]).to eq(:pundit)
    end

    it "classifies auth.method as :devise" do
      expect(result[:auth][:method]).to eq(:devise)
    end

    it "exposes auth flags" do
      expect(result[:auth]).to include(
        devise: true,
        omniauth: false,
        omniauth_openid_connect: false,
        warden: false,
        jwt: false,
        basic_auth: false
      )
    end

    it "detects RSpec test framework" do
      expect(result[:test_framework]).to eq(:rspec)
    end

    it "detects SolidQueue as a background job processor" do
      expect(result[:background_jobs]).to contain_exactly(:solid_queue)
    end

    it "reports no API v1 when routes have none" do
      expect(result[:has_api_v1]).to be(false)
    end

    it "reports no Bootstrap when nothing references it" do
      expect(result[:has_bootstrap]).to be(false)
    end

    it "lists ApplicationController includes" do
      expect(result[:application_controller_includes])
        .to contain_exactly("Pundit::Authorization", "OperationsMethods")
    end

    it "returns an empty list when no concept folders exist" do
      expect(result[:concept_folders]).to eq([])
    end

    it "reports api_only false for a default Rails app" do
      expect(result[:api_only]).to be(false)
    end

    it "reports engine_host false for a default Rails app" do
      expect(result[:engine_host]).to be(false)
    end
  end

  describe "API-only detection" do
    it "reports api_only=true and template_engine=nil for `config.api_only = true`" do
      with_dummy_app do |tmp|
        File.write(
          "#{tmp}/config/application.rb",
          <<~RUBY
            require "rails/all"
            module DummyApp
              class Application < Rails::Application
                config.api_only = true
              end
            end
          RUBY
        )
        result = described_class.run(root: tmp)
        expect(result[:api_only]).to be(true)
        expect(result[:template_engine]).to be_nil
      end
    end
  end

  describe "engine-host detection" do
    it "reports engine_host=true when application class inherits from Rails::Engine" do
      with_dummy_app do |tmp|
        File.write(
          "#{tmp}/config/application.rb",
          <<~RUBY
            module DummyEngine
              class Engine < Rails::Engine
              end
            end
          RUBY
        )
        result = described_class.run(root: tmp)
        expect(result[:engine_host]).to be(true)
      end
    end
  end

  describe "concept folders" do
    it "lists folders alphabetically and excludes 'base'" do
      with_dummy_app do |tmp|
        FileUtils.mkdir_p("#{tmp}/app/concepts/base/operation")
        FileUtils.mkdir_p("#{tmp}/app/concepts/crm/property")
        FileUtils.mkdir_p("#{tmp}/app/concepts/admin")
        result = described_class.run(root: tmp)
        expect(result[:concept_folders]).to eq(%w[admin crm])
      end
    end
  end

  describe "/api/v1 routes" do
    it "detects nested namespace style" do
      with_dummy_app do |tmp|
        File.write(
          "#{tmp}/config/routes.rb",
          <<~RUBY
            Rails.application.routes.draw do
              namespace :api do
                namespace :v1 do
                  resources :users
                end
              end
            end
          RUBY
        )
        expect(described_class.run(root: tmp)[:has_api_v1]).to be(true)
      end
    end

    it "detects scope-string style" do
      with_dummy_app do |tmp|
        File.write(
          "#{tmp}/config/routes.rb",
          <<~RUBY
            Rails.application.routes.draw do
              scope "api/v1" do
                resources :users
              end
            end
          RUBY
        )
        expect(described_class.run(root: tmp)[:has_api_v1]).to be(true)
      end
    end

    it "detects controller-folder style" do
      with_dummy_app do |tmp|
        FileUtils.mkdir_p("#{tmp}/app/controllers/api/v1")
        File.write("#{tmp}/app/controllers/api/v1/users_controller.rb", "class Api::V1::UsersController; end\n")
        expect(described_class.run(root: tmp)[:has_api_v1]).to be(true)
      end
    end
  end

  describe "auth detection (broad)" do
    it "classifies a custom `def current_user` as :custom" do
      with_dummy_app do |tmp|
        File.write(
          "#{tmp}/app/controllers/application_controller.rb",
          <<~RUBY
            class ApplicationController < ActionController::Base
              def current_user
                @current_user ||= User.find_by(id: session[:user_id])
              end
            end
          RUBY
        )
        # Replace Devise gem in lockfile so devise check returns false.
        lock = File.read("#{tmp}/Gemfile.lock").gsub(/^\s+devise \([^)]*\)\n/, "")
        File.write("#{tmp}/Gemfile.lock", lock)

        result = described_class.run(root: tmp)
        expect(result[:auth][:method]).to eq(:custom)
        expect(result[:auth][:custom_current_user]).to be(true)
        expect(result[:auth][:devise]).to be(false)
      end
    end

    it "classifies BasicAuth as :basic_auth" do
      with_dummy_app do |tmp|
        File.write(
          "#{tmp}/app/controllers/application_controller.rb",
          <<~RUBY
            class ApplicationController < ActionController::Base
              before_action :authenticate
              def authenticate
                authenticate_or_request_with_http_basic do |u, p|
                  u == "admin" && p == "secret"
                end
              end
            end
          RUBY
        )
        File.write("#{tmp}/Gemfile.lock", File.read("#{tmp}/Gemfile.lock").gsub(/^\s+devise \([^)]*\)\n/, ""))

        result = described_class.run(root: tmp)
        expect(result[:auth][:method]).to eq(:basic_auth)
        expect(result[:auth][:basic_auth]).to be(true)
      end
    end

    it "classifies JWT as :jwt" do
      with_dummy_app do |tmp|
        File.write("#{tmp}/Gemfile.lock", File.read("#{tmp}/Gemfile.lock").gsub(/^\s+devise \([^)]*\)\n/, ""))
        File.write("#{tmp}/Gemfile.lock", "#{File.read("#{tmp}/Gemfile.lock")}\n    jwt (2.7.1)\n")

        result = described_class.run(root: tmp)
        expect(result[:auth][:method]).to eq(:jwt)
        expect(result[:auth][:jwt]).to be(true)
      end
    end
  end

  describe "multi-DB detection" do
    it "lists all configured databases when database.yml has named entries" do
      with_dummy_app do |tmp|
        FileUtils.mkdir_p("#{tmp}/config")
        File.write(
          "#{tmp}/config/database.yml",
          <<~YAML
            default: &default
              adapter: postgresql
              encoding: unicode
              pool: 5

            development:
              primary:
                <<: *default
                database: dummy_dev
              queue:
                <<: *default
                database: dummy_queue
              cache:
                <<: *default
                database: dummy_cache
              cable:
                <<: *default
                database: dummy_cable
          YAML
        )
        expect(described_class.run(root: tmp)[:databases]).to eq(%w[cable cache primary queue])
      end
    end

    it "returns ['primary'] for legacy single-DB shape" do
      with_dummy_app do |tmp|
        FileUtils.mkdir_p("#{tmp}/config")
        File.write(
          "#{tmp}/config/database.yml",
          <<~YAML
            default: &default
              adapter: postgresql
              encoding: unicode

            development:
              <<: *default
              database: dummy_dev
          YAML
        )
        expect(described_class.run(root: tmp)[:databases]).to eq(["primary"])
      end
    end

    it "tolerates ERB inside database.yml" do
      with_dummy_app do |tmp|
        FileUtils.mkdir_p("#{tmp}/config")
        File.write(
          "#{tmp}/config/database.yml",
          <<~YAML
            development:
              primary:
                adapter: postgresql
                database: <%= ENV["DB_NAME"] %>
          YAML
        )
        expect { described_class.run(root: tmp) }.not_to raise_error
      end
    end
  end

  describe ".run on an empty directory" do
    let(:project_root) { Dir.mktmpdir("tsykvas-probe-spec-empty-") }
    after { FileUtils.remove_entry(project_root) if Dir.exist?(project_root) }

    it "returns sensible defaults without raising" do
      result = described_class.run(root: project_root)
      expect(result[:ruby_version]).to be_nil
      expect(result[:rails_version]).to be_nil
      expect(result[:default_branch]).to be_nil
      expect(result[:template_engine]).to eq(:erb)
      expect(result[:authorization]).to eq(:none)
      expect(result[:auth][:method]).to eq(:none)
      expect(result[:test_framework]).to eq(:minitest)
      expect(result[:background_jobs]).to eq([])
      expect(result[:concept_folders]).to eq([])
      expect(result[:application_controller_includes]).to eq([])
      expect(result[:api_only]).to be(false)
      expect(result[:engine_host]).to be(false)
      expect(result[:databases]).to eq([])
    end
  end
end
