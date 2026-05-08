# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "thor"
require "rails/generators"
require_relative "../../lib/generators/tsykvas_rails_template/companions/companions_generator"

RSpec.describe TsykvasRailsTemplate::Generators::CompanionsGenerator do
  fixture = File.expand_path("../fixtures/dummy_app", __dir__)

  around do |example|
    Dir.mktmpdir("tsykvas-companions-spec-") do |tmp|
      FileUtils.cp_r("#{fixture}/.", tmp)
      @destination = tmp
      example.run
    end
  end

  def run_generator(args = [])
    described_class.start(
      args + %w[--skip-bundle --skip-post-install],
      destination_root: @destination,
      shell: Thor::Shell::Basic.new
    )
  end

  def gemfile
    File.read(File.join(@destination, "Gemfile"))
  end

  describe "options" do
    let(:option_names) { described_class.class_options.keys }

    %i[skip_auth skip_forms skip_images skip_jobs_ui skip_test skip_dev
       skip_bundle skip_post_install].each do |opt|
      it "exposes --#{opt.to_s.tr("_", "-")}" do
        expect(option_names).to include(opt)
      end
    end
  end

  describe "bundle install regression (no bundle_command)" do
    # `bundle_command` lives on Rails::Generators::AppBase, not on
    # Rails::Generators::Base which we inherit from. A previous version
    # called bundle_command directly and crashed at runtime. Use
    # Bundler.with_unbundled_env { run "bundle install" } instead.
    let(:source) do
      Pathname(__dir__).parent.parent.join(
        "lib/generators/tsykvas_rails_template/companions/companions_generator.rb"
      ).read
    end

    it "does not call the unsupported bundle_command method" do
      expect(source).not_to match(/\bbundle_command\b/),
                            "`bundle_command` is undefined on Rails::Generators::Base; use " \
                            "`Bundler.with_unbundled_env { run \"bundle install\" }` instead."
    end

    it "uses Bundler.with_unbundled_env for env isolation" do
      expect(source).to match(/Bundler\.with_unbundled_env/)
    end
  end

  describe "default run (all groups, skip-bundle, skip-post-install)" do
    before { run_generator }

    it "adds devise" do
      expect(gemfile).to match(/^gem ['"]devise['"]/)
    end

    it "adds omniauth-rails_csrf_protection" do
      expect(gemfile).to match(/^gem ['"]omniauth-rails_csrf_protection['"]/)
    end

    it "adds simple_form" do
      expect(gemfile).to match(/^gem ['"]simple_form['"]/)
    end

    it "adds mini_magick" do
      expect(gemfile).to match(/^gem ['"]mini_magick['"]/)
    end

    it "adds rspec-rails in development+test group" do
      expect(gemfile).to match(/group :development, :test do.*rspec-rails/m)
    end

    it "adds factory_bot_rails" do
      expect(gemfile).to match(/['"]factory_bot_rails['"]/)
    end

    it "adds shoulda-matchers in test-only group" do
      expect(gemfile).to match(/group :test do.*shoulda-matchers/m)
    end

    it "adds webmock" do
      expect(gemfile).to match(/['"]webmock['"]/)
    end

    it "adds faker" do
      expect(gemfile).to match(/['"]faker['"]/)
    end

    it "adds dotenv-rails" do
      expect(gemfile).to match(/['"]dotenv-rails['"]/)
    end

    it "adds mission_control-jobs (dummy fixture has solid_queue)" do
      expect(gemfile).to match(/['"]mission_control-jobs['"]/)
    end
  end

  describe "MissionControl::Jobs gating" do
    it "is added when solid_queue is in Gemfile.lock" do
      run_generator
      expect(gemfile).to match(/mission_control-jobs/)
    end

    it "is NOT added when solid_queue is absent" do
      lock_path = File.join(@destination, "Gemfile.lock")
      File.write(lock_path, File.read(lock_path).gsub(/^\s+solid_queue \([^)]*\)\n/, ""))

      run_generator
      expect(gemfile).not_to match(/mission_control-jobs/)
    end
  end

  describe "opt-out flags" do
    it "--skip-auth omits devise + omniauth" do
      run_generator(%w[--skip-auth])
      expect(gemfile).not_to match(/['"]devise['"]/)
      expect(gemfile).not_to match(/omniauth-rails_csrf_protection/)
    end

    it "--skip-forms omits simple_form" do
      run_generator(%w[--skip-forms])
      expect(gemfile).not_to match(/['"]simple_form['"]/)
    end

    it "--skip-images omits mini_magick" do
      run_generator(%w[--skip-images])
      expect(gemfile).not_to match(/['"]mini_magick['"]/)
    end

    it "--skip-jobs-ui omits mission_control-jobs even with solid_queue present" do
      run_generator(%w[--skip-jobs-ui])
      expect(gemfile).not_to match(/mission_control-jobs/)
    end

    it "--skip-test omits the rspec stack" do
      run_generator(%w[--skip-test])
      expect(gemfile).not_to match(/rspec-rails/)
      expect(gemfile).not_to match(/factory_bot_rails/)
      expect(gemfile).not_to match(/shoulda-matchers/)
      expect(gemfile).not_to match(/['"]webmock['"]/)
      expect(gemfile).not_to match(/['"]faker['"]/)
    end

    it "--skip-dev omits dotenv-rails" do
      run_generator(%w[--skip-dev])
      expect(gemfile).not_to match(/dotenv-rails/)
    end
  end

  describe "idempotency: re-runs don't duplicate Gemfile entries" do
    before do
      run_generator
      run_generator(%w[--force])
    end

    %w[devise simple_form mini_magick rspec-rails dotenv-rails mission_control-jobs].each do |gem_name|
      it "lists #{gem_name} exactly once" do
        expect(gemfile.scan(/['"]#{Regexp.escape(gem_name)}['"]/).count).to eq(1)
      end
    end
  end

  describe "post-install integration (skip-bundle but allow post-install)" do
    # The :install sub-generators (devise:install, simple_form:install,
    # rspec:install) require their gems to be loadable, which requires
    # `bundle install` to have run. We can't run real `bundle install` in
    # specs (slow + network). Instead we test the SKIP logic — generator
    # detects existing config files and skips the sub-generator call.

    before do
      # Pretend each sub-generator already ran by creating its canonical
      # config file. The companions generator should then skip the sub-call.
      FileUtils.mkdir_p(File.join(@destination, "config/initializers"))
      File.write(File.join(@destination, "config/initializers/devise.rb"), "# already configured\n")
      File.write(File.join(@destination, "config/initializers/simple_form.rb"), "# already configured\n")
      FileUtils.mkdir_p(File.join(@destination, "spec"))
      File.write(File.join(@destination, "spec/rails_helper.rb"),
                 "RSpec.configure do |config|\nend\n")
    end

    it "doesn't crash when sub-generators are skipped (configs already exist)" do
      expect do
        described_class.start(
          %w[--skip-bundle],
          destination_root: @destination,
          shell: Thor::Shell::Basic.new
        )
      end.not_to raise_error
    end

    it "appends shoulda-matchers config to existing rails_helper.rb" do
      described_class.start(
        %w[--skip-bundle],
        destination_root: @destination,
        shell: Thor::Shell::Basic.new
      )
      expect(File.read(File.join(@destination, "spec/rails_helper.rb")))
        .to include("Shoulda::Matchers.configure")
    end

    it "appends webmock config to existing rails_helper.rb" do
      described_class.start(
        %w[--skip-bundle],
        destination_root: @destination,
        shell: Thor::Shell::Basic.new
      )
      expect(File.read(File.join(@destination, "spec/rails_helper.rb")))
        .to include("WebMock.disable_net_connect!(allow_localhost: true)")
    end

    it "doesn't duplicate config blocks on re-run" do
      2.times do
        described_class.start(
          %w[--skip-bundle --force],
          destination_root: @destination,
          shell: Thor::Shell::Basic.new
        )
      end
      helper = File.read(File.join(@destination, "spec/rails_helper.rb"))
      expect(helper.scan(/Shoulda::Matchers\.configure/).count).to eq(1)
      expect(helper.scan(/WebMock\.disable_net_connect/).count).to eq(1)
    end
  end

  describe "MissionControl::Jobs route mount" do
    # Focus: just the route-mount post-install. Skip every other group so we
    # don't shell out to non-existent bin/rails for sub-generators.
    JOBS_ONLY = %w[--skip-bundle --skip-auth --skip-forms --skip-images --skip-test --skip-dev].freeze # rubocop:disable Lint/ConstantDefinitionInBlock

    before do
      FileUtils.mkdir_p(File.join(@destination, "config"))
      File.write(File.join(@destination, "config/routes.rb"),
                 "Rails.application.routes.draw do\nend\n")
    end

    it "injects an admin-only mount when solid_queue is present" do
      described_class.start(JOBS_ONLY, destination_root: @destination, shell: Thor::Shell::Basic.new)
      routes = File.read(File.join(@destination, "config/routes.rb"))
      expect(routes).to include("MissionControl::Jobs::Engine")
      expect(routes).to include('at: "/jobs"')
      expect(routes).to include("user.admin?")
      expect(routes).to include('req.env["warden"]')
    end

    it "doesn't duplicate the mount on re-run" do
      2.times do
        described_class.start(JOBS_ONLY + %w[--force], destination_root: @destination, shell: Thor::Shell::Basic.new)
      end
      routes = File.read(File.join(@destination, "config/routes.rb"))
      expect(routes.scan(/MissionControl::Jobs::Engine/).count).to eq(1)
    end

    it "doesn't mount when --skip-jobs-ui" do
      described_class.start(
        %w[--skip-bundle --skip-auth --skip-forms --skip-images --skip-test --skip-dev --skip-jobs-ui],
        destination_root: @destination, shell: Thor::Shell::Basic.new
      )
      routes = File.read(File.join(@destination, "config/routes.rb"))
      expect(routes).not_to include("MissionControl::Jobs::Engine")
    end
  end

  describe ".gitignore handling" do
    DEV_ONLY = %w[--skip-bundle --skip-auth --skip-forms --skip-images --skip-jobs-ui --skip-test].freeze # rubocop:disable Lint/ConstantDefinitionInBlock

    before do
      File.write(File.join(@destination, ".gitignore"), "/.bundle/\n")
    end

    it "appends .env rules" do
      described_class.start(DEV_ONLY, destination_root: @destination, shell: Thor::Shell::Basic.new)
      gitignore = File.read(File.join(@destination, ".gitignore"))
      expect(gitignore).to include(".env\n")
      expect(gitignore).to include("!.env.example")
    end

    it "doesn't append twice on re-run" do
      2.times do
        described_class.start(DEV_ONLY + %w[--force], destination_root: @destination, shell: Thor::Shell::Basic.new)
      end
      gitignore = File.read(File.join(@destination, ".gitignore"))
      expect(gitignore.scan(/^\.env$/).count).to eq(1)
    end
  end

  describe "version-bump pipeline" do
    let(:public_methods) { described_class.instance_methods(false).map(&:to_s) }

    it "exposes a `bundle_update_companions` action so re-runs bump pinned gems to latest" do
      expect(public_methods).to include("bundle_update_companions")
    end

    it "runs bundle_update AFTER add_*_gems and run_bundle_install (declaration order is action order in Thor)" do
      decl_order = public_methods
      add_idx = decl_order.index("add_top_level_gems")
      install_idx = decl_order.index("run_bundle_install")
      update_idx = decl_order.index("bundle_update_companions")

      expect(add_idx).to be < install_idx
      expect(install_idx).to be < update_idx
    end
  end
end
