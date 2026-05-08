# frozen_string_literal: true

require "spec_helper"
require "pathname"
require "rails/generators"
require_relative "../../lib/generators/tsykvas_rails_template/install/install_generator"

RSpec.describe TsykvasRailsTemplate::Generators::InstallGenerator do
  let(:templates_dir) { Pathname(described_class.source_root) }

  it "exposes a source_root that exists on disk" do
    expect(templates_dir).to be_directory
  end

  describe "shipped Ruby base templates" do
    %w[
      app/concepts/base/operation/base.rb
      app/concepts/base/operation/result.rb
      app/concepts/base/component/base.rb
      app/controllers/concerns/operations_methods.rb
      app/controllers/home_controller.rb
      app/concepts/home/operation/index.rb
      app/concepts/home/component/index.rb
      app/concepts/home/component/index.html.slim
      app/policies/application_policy.rb
      app/policies/home_policy.rb
    ].each do |path|
      it "ships #{path}" do
        expect(templates_dir.join(path)).to be_file
      end
    end
  end

  describe "shipped Claude payload" do
    %w[buddy code-reviewer security-reviewer tech-lead].each do |agent|
      it "ships .claude/agents/#{agent}.md" do
        expect(templates_dir.join(".claude/agents/#{agent}.md")).to be_file
      end
    end

    %w[
      check
      code-review
      docs-create
      pr-review
      pushit
      refactor
      tsykvas-claude
      task-sum
      tests
      update-docs
      update-rules
      update-tests
    ].each do |cmd|
      it "ships .claude/commands/#{cmd}.md" do
        expect(templates_dir.join(".claude/commands/#{cmd}.md")).to be_file
      end
    end

    # All 20 docs ship at install. The 3 gem-canonical
    # (`tsykvas_rails_template.md`, `forms.md`, `companions.md`) stay
    # verbatim; the other 17 may be refreshed by `/tsykvas-claude` to
    # reflect host-specific stack details.
    %w[
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
    ].each do |doc|
      it "ships .claude/docs/#{doc}.md" do
        expect(templates_dir.join(".claude/docs/#{doc}.md")).to be_file
      end
    end

    it "no longer keeps a `_generated/` subdir (docs ship to .claude/docs/ directly)" do
      expect(templates_dir.join(".claude/docs/_generated")).not_to exist
    end
  end

  describe "CLAUDE.md.tt fence integrity" do
    let(:content) { templates_dir.join("CLAUDE.md.tt").read }

    it "contains at least one fence pair" do
      expect(content.scan(/<!-- tsykvas-template:start v=/).count).to be > 0
    end

    it "has matching start/end markers" do
      starts = content.scan(/<!-- tsykvas-template:start v=/).count
      ends = content.scan(/<!-- tsykvas-template:end -->/).count
      expect(starts).to eq(ends)
    end

    it "fences the routing section" do
      expect(content).to match(/<!-- tsykvas-template:start v=[\d.]+ section=routing -->/)
    end

    it "fences the tldr section" do
      expect(content).to match(/<!-- tsykvas-template:start v=[\d.]+ section=tldr -->/)
    end

    it "fences the tree section" do
      expect(content).to match(/<!-- tsykvas-template:start v=[\d.]+ section=tree -->/)
    end

    it "links to forms.md from the routing table (Form-object rule must survive every reinit)" do
      expect(content).to include("[.claude/docs/forms.md](.claude/docs/forms.md)")
    end

    # Slash commands + subagents intentionally don't get a section here —
    # they live in .claude/{commands,agents}/. Keep CLAUDE.md focused on docs.
    it "does NOT advertise slash commands or subagents inside CLAUDE.md" do
      expect(content).not_to match(/^## Slash commands/i)
      expect(content).not_to match(/^## Subagents/i)
    end
  end

  describe "CLAUDE.md.tt token-economy budget" do
    # CLAUDE.md is loaded into every Claude session's context. Keep it ≤ 100
    # lines on initial install AND on every /tsykvas-claude rewrite.
    # Push detail into .claude/docs/<topic>.md and link out from the routing
    # table. /tsykvas-claude Phase 5 enforces the same budget at runtime.

    let(:line_count) { templates_dir.join("CLAUDE.md.tt").readlines.count }

    it "is ≤ 100 lines (token-economy budget enforced at install time)" do
      expect(line_count).to be <= 100,
                            "CLAUDE.md.tt is #{line_count} lines; max 100. " \
                            "Push detail into .claude/docs/<topic>.md and link from the routing table."
    end

    it "documents the 100-line rule in the file itself" do
      expect(templates_dir.join("CLAUDE.md.tt").read).to include("≤ 100 lines")
    end
  end

  describe "/tsykvas-claude enforces the 100-line budget" do
    let(:reinit_body) { templates_dir.join(".claude/commands/tsykvas-claude.md").read }

    it "names the 100-line cap as a HARD GATE in Phase 5" do
      expect(reinit_body).to include("HARD GATE")
      expect(reinit_body).to include("≤ 100 lines")
    end

    it "instructs Phase 2a planning to budget against 100 lines up front" do
      expect(reinit_body).to match(/Phase 2a.*Budget.*100 lines/m)
    end

    it "explains the token-economy reason (not just the rule)" do
      expect(reinit_body).to match(/token-economy|token tax|per-prompt token/i)
    end
  end

  describe "operation scaffolds (concept generator)" do
    let(:concept_templates) do
      Pathname(__dir__).parent.parent.join(
        "lib/generators/tsykvas_rails_template/concept/templates"
      )
    end

    it "ships create.rb.tt that points at .claude/docs/forms.md" do
      content = concept_templates.join("operation/create.rb.tt").read
      expect(content).to include(".claude/docs/forms.md")
    end

    it "ships update.rb.tt that points at .claude/docs/forms.md" do
      content = concept_templates.join("operation/update.rb.tt").read
      expect(content).to include(".claude/docs/forms.md")
    end

    it "ships only Slim view templates (no leftover ERB)" do
      slim_templates = Dir.glob(concept_templates.join("component/*.html.slim.tt").to_s)
      erb_templates = Dir.glob(concept_templates.join("component/*.html.erb.tt").to_s)
      expect(slim_templates.count).to eq(4)
      expect(erb_templates).to be_empty
    end
  end

  describe "generator declares expected actions" do
    let(:public_methods) { described_class.instance_methods(false).map(&:to_s) }

    %w[
      swap_database_to_postgresql
      copy_concepts_base
      copy_operations_methods_concern
      add_concepts_to_autoload_paths
      wire_application_controller
      create_application_policy
      generate_home_example
      add_root_route
      install_bootstrap
      clean_propshaft_cache
      copy_claude_payload
      write_claude_md
      announce_completion
    ].each do |action|
      it "exposes #{action}" do
        expect(public_methods).to include(action)
      end
    end
  end

  describe "clean_propshaft_cache" do
    require "fileutils"
    require "tmpdir"

    fixture = File.expand_path("../fixtures/dummy_app", __dir__)

    around do |example|
      Dir.mktmpdir("tsykvas-propshaft-cache-spec-") do |tmp|
        FileUtils.cp_r("#{fixture}/.", tmp)
        FileUtils.mkdir_p("#{tmp}/public/assets")
        File.write("#{tmp}/public/assets/.manifest.json", "{}")
        File.write("#{tmp}/public/assets/application-stale.css", "/* stale */")
        @destination = tmp
        example.run
      end
    end

    def run_generator(args = [])
      described_class.start(
        args + %w[--skip-bootstrap --skip-claude --skip-home-example],
        destination_root: @destination,
        shell: Thor::Shell::Basic.new
      )
    end

    it "removes public/assets/ when .gitignore lists it (the rails-new default)" do
      File.write(File.join(@destination, ".gitignore"), "/public/assets\n")
      run_generator
      expect(File.directory?(File.join(@destination, "public/assets"))).to be(false)
    end

    it "leaves public/assets/ alone when .gitignore does NOT list it" do
      File.write(File.join(@destination, ".gitignore"), "")
      run_generator
      expect(File.directory?(File.join(@destination, "public/assets"))).to be(true)
      expect(File.exist?(File.join(@destination, "public/assets/.manifest.json"))).to be(true)
    end
  end

  describe "opt-out flags" do
    let(:option_names) { described_class.class_options.keys }

    it { expect(option_names).to include(:skip_application_policy) }
    it { expect(option_names).to include(:skip_autoload_paths) }
    it { expect(option_names).to include(:skip_claude) }
    it { expect(option_names).to include(:skip_home_example) }
    it { expect(option_names).to include(:keep_sqlite) }
    it { expect(option_names).to include(:skip_bootstrap) }
    it { expect(option_names).not_to include(:assume_auth) }
  end

  describe "BootstrapInstaller install pipeline" do
    require_relative "../../lib/generators/tsykvas_rails_template/install/bootstrap_installer"

    let(:installer_methods) do
      TsykvasRailsTemplate::Generators::BootstrapInstaller.private_instance_methods(false).map(&:to_s)
    end

    %w[
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
    ].each do |step|
      it "exposes private step #{step}" do
        expect(installer_methods).to include(step)
      end
    end
  end

  describe "BootstrapInstaller initializer" do
    let(:body) { TsykvasRailsTemplate::Generators::BootstrapInstaller::DARTSASS_INITIALIZER_BODY }

    it "passes --quiet-deps so upstream Bootstrap SCSS deprecation warnings stay muted" do
      expect(body).to include("dartsass.build_options")
      expect(body).to include("--quiet-deps")
    end

    it "passes --silence-deprecation=import so the user's `@import \"bootstrap\"` is muted" do
      expect(body).to include("--silence-deprecation=import")
    end

    # Regression: an earlier version assigned a String, which crashes
    # dartsass-rails' runner (`build_options.flat_map(&:split)`).
    it "assigns build_options as an Array (Strings break dartsass-rails)" do
      expect(body).to match(/build_options\s*=\s*\[/m)
    end

    it "preserves dartsass-rails' compressed + no-source-map defaults" do
      expect(body).to include("--style=compressed")
      expect(body).to include("--no-source-map")
    end
  end

  describe "shipped docs are project-agnostic (no sport / heritage residue)" do
    let(:docs_dir) { templates_dir.join(".claude/docs") }

    %w[
      sport
      "Run Club"
      Heritage
      "cream paper"
      "forest green"
      "rust accent"
      \bEST\b
      "Cream Paper"
      "Ink Black"
    ].each do |token|
      it "no doc references `#{token}`" do
        hits = Dir.glob(docs_dir.join("*.md")).flat_map do |path|
          File.readlines(path).each_with_index.filter_map do |line, idx|
            next unless line.match?(/#{token}/i)

            "#{File.basename(path)}:#{idx + 1}: #{line.strip}"
          end
        end
        expect(hits).to be_empty, "Found sport-specific token in shipped docs:\n#{hits.join("\n")}"
      end
    end
  end

  describe "README onboarding coverage" do
    let(:readme) { templates_dir.parent.parent.parent.parent.parent.join("README.md").read }

    it "has a Troubleshooting section" do
      expect(readme).to match(/^## Troubleshooting/m)
    end

    it "documents the --skip-bootstrap flag" do
      expect(readme).to include("--skip-bootstrap")
    end

    it "mentions the auto-installed foreman" do
      expect(readme).to include("foreman")
    end

    it "explains the silenced dartsass deprecation warnings" do
      expect(readme).to include("--quiet-deps")
    end
  end

  describe "Home component template (Bootstrap demo)" do
    let(:slim_path) { templates_dir.join("app/concepts/home/component/index.html.slim") }
    let(:slim) { slim_path.read }

    it "is parseable Slim (regression: leading-`/` content used to crash)" do
      require "slim"
      expect { Slim::Template.new { slim } }.not_to raise_error
    end

    it "renders Bootstrap demo elements (card + alert + modal trigger)" do
      expect(slim).to include(".card")
      expect(slim).to include("alert-success")
      expect(slim).to include('data-bs-toggle="modal"')
      expect(slim).to include("#tsykvasWelcomeModal.modal.fade")
    end
  end

  describe "CLAUDE.md preservation (claude-init-first workflow)" do
    require "fileutils"
    require "tmpdir"

    fixture = File.expand_path("../fixtures/dummy_app", __dir__)

    around do |example|
      Dir.mktmpdir("tsykvas-claude-md-spec-") do |tmp|
        FileUtils.cp_r("#{fixture}/.", tmp)
        @destination = tmp
        example.run
      end
    end

    it "does NOT overwrite an existing CLAUDE.md" do
      user_content = "# My App\n\nUser-authored CLAUDE.md from `claude init`.\n"
      File.write(File.join(@destination, "CLAUDE.md"), user_content)

      described_class.start(
        %w[--skip-home-example],
        destination_root: @destination,
        shell: Thor::Shell::Basic.new
      )

      expect(File.read(File.join(@destination, "CLAUDE.md"))).to eq(user_content)
    end

    it "creates CLAUDE.md from template when none exists" do
      claude_md = File.join(@destination, "CLAUDE.md")
      expect(File.exist?(claude_md)).to be(false)

      described_class.start(
        %w[--skip-home-example],
        destination_root: @destination,
        shell: Thor::Shell::Basic.new
      )

      expect(File.exist?(claude_md)).to be(true)
      expect(File.read(claude_md)).to include("tsykvas-template:start")
    end
  end

  describe "Home example concept" do
    require "fileutils"
    require "tmpdir"

    fixture = File.expand_path("../fixtures/dummy_app", __dir__)

    around do |example|
      Dir.mktmpdir("tsykvas-home-spec-") do |tmp|
        FileUtils.cp_r("#{fixture}/.", tmp)
        FileUtils.mkdir_p("#{tmp}/config")
        File.write("#{tmp}/config/routes.rb", "Rails.application.routes.draw do\nend\n")
        @destination = tmp
        example.run
      end
    end

    it "scaffolds HomeController + concepts/home + HomePolicy + root route by default" do
      described_class.start([], destination_root: @destination, shell: Thor::Shell::Basic.new)

      expect(File.exist?(File.join(@destination, "app/controllers/home_controller.rb"))).to be(true)
      expect(File.exist?(File.join(@destination, "app/concepts/home/operation/index.rb"))).to be(true)
      expect(File.exist?(File.join(@destination, "app/concepts/home/component/index.rb"))).to be(true)
      expect(File.exist?(File.join(@destination, "app/concepts/home/component/index.html.slim"))).to be(true)
      expect(File.exist?(File.join(@destination, "app/policies/home_policy.rb"))).to be(true)
      expect(File.read(File.join(@destination, "config/routes.rb"))).to include('root "home#index"')
    end

    it "ships HomeController as a one-line `endpoint` example (canonical pattern)" do
      described_class.start([], destination_root: @destination, shell: Thor::Shell::Basic.new)

      controller = File.read(File.join(@destination, "app/controllers/home_controller.rb"))
      expect(controller).to match(/^\s*endpoint Home::Operation::Index, Home::Component::Index\s*$/)
      expect(controller).not_to include("Home::Operation::Index.call")
      expect(controller).not_to include("render Home::Component::Index.new")
    end

    it "ships HomePolicy that allows the public landing page (`def index? = true`)" do
      described_class.start([], destination_root: @destination, shell: Thor::Shell::Basic.new)

      policy = File.read(File.join(@destination, "app/policies/home_policy.rb"))
      expect(policy).to match(/class HomePolicy < ApplicationPolicy/)
      expect(policy).to match(/def index\?\s*=\s*true/)
    end

    it "ships Home::Operation::Index that demonstrates `authorize!` + OpenStruct model" do
      described_class.start([], destination_root: @destination, shell: Thor::Shell::Basic.new)

      operation = File.read(File.join(@destination, "app/concepts/home/operation/index.rb"))
      expect(operation).to include("authorize! :home, :index?")
      expect(operation).to include("skip_policy_scope")
      expect(operation).to include("OpenStruct.new")
    end

    it "honours --skip-home-example" do
      described_class.start(
        %w[--skip-home-example],
        destination_root: @destination, shell: Thor::Shell::Basic.new
      )

      expect(File.exist?(File.join(@destination, "app/controllers/home_controller.rb"))).to be(false)
      expect(File.directory?(File.join(@destination, "app/concepts/home"))).to be(false)
      expect(File.exist?(File.join(@destination, "app/policies/home_policy.rb"))).to be(false)
      expect(File.read(File.join(@destination, "config/routes.rb"))).not_to include("home#index")
    end

    it "doesn't add a root route if one already exists" do
      File.write("#{@destination}/config/routes.rb",
                 "Rails.application.routes.draw do\n  root \"existing#index\"\nend\n")

      described_class.start([], destination_root: @destination, shell: Thor::Shell::Basic.new)

      routes = File.read(File.join(@destination, "config/routes.rb"))
      expect(routes.scan(/^\s*root\s/).count).to eq(1)
      expect(routes).to include("existing#index")
    end

    it "skips home scaffold when HomeController already exists" do
      FileUtils.mkdir_p("#{@destination}/app/controllers")
      stub = "class HomeController < ApplicationController\nend\n"
      File.write("#{@destination}/app/controllers/home_controller.rb", stub)

      described_class.start([], destination_root: @destination, shell: Thor::Shell::Basic.new)

      expect(File.read(File.join(@destination, "app/controllers/home_controller.rb"))).to eq(stub)
    end
  end

  describe "OperationsMethods is auth-agnostic" do
    let(:concern_path) do
      templates_dir.join("app/controllers/concerns/operations_methods.rb")
    end

    # Without `try`, calling `endpoint` on a host that hasn't wired Devise
    # (or any other current_user source) would raise NoMethodError. The
    # gem ships the home example as a one-line `endpoint` call, so the
    # concern must work on a vanilla Rails app.
    it "calls the operation with `try(:current_user)` so endpoint works without Devise" do
      expect(concern_path.read).to include("operation.call(params:, current_user: try(:current_user))")
    end

    it "does NOT call bare `current_user` (would NoMethodError on auth-less hosts)" do
      expect(concern_path.read).not_to match(/operation\.call\(params:, current_user:\)/)
    end
  end

  describe "wire_application_controller is unconditional" do
    require "fileutils"
    require "tmpdir"

    fixture = File.expand_path("../fixtures/dummy_app", __dir__)

    around do |example|
      Dir.mktmpdir("tsykvas-wire-spec-") do |tmp|
        FileUtils.cp_r("#{fixture}/.", tmp)
        # Replace the fixture's pre-wired ApplicationController with a
        # vanilla one (mimics a fresh `rails new` host).
        File.write(
          File.join(tmp, "app/controllers/application_controller.rb"),
          "# frozen_string_literal: true\n\nclass ApplicationController < ActionController::Base\nend\n"
        )
        # Drop devise from Gemfile.lock so old auth-detection paths can't
        # masquerade as the reason wiring happens.
        gemfile_lock = File.join(tmp, "Gemfile.lock")
        File.write(gemfile_lock, File.read(gemfile_lock).gsub(/^\s+devise.*$/, "")) if File.exist?(gemfile_lock)
        @destination = tmp
        example.run
      end
    end

    it "wires Pundit + OperationsMethods even when no auth source is present" do
      described_class.start(
        %w[--skip-claude --skip-home-example],
        destination_root: @destination, shell: Thor::Shell::Basic.new
      )

      ac = File.read(File.join(@destination, "app/controllers/application_controller.rb"))
      expect(ac).to include("include Pundit::Authorization")
      expect(ac).to include("include OperationsMethods")
    end
  end

  describe "shipped Base templates require their gems" do
    let(:templates_dir) { Pathname(described_class.source_root) }

    it "Base::Component::Base requires view_component (avoids zeitwerk:check failure)" do
      expect(templates_dir.join("app/concepts/base/component/base.rb").read)
        .to include('require "view_component"')
    end

    it "Base::Operation::Base requires pundit (avoids load order issue)" do
      expect(templates_dir.join("app/concepts/base/operation/base.rb").read)
        .to include('require "pundit"')
    end
  end

  describe "idempotency on re-runs (B3)" do
    require "fileutils"
    require "tmpdir"
    require "rails/generators/testing/behavior"

    fixture = File.expand_path("../fixtures/dummy_app", __dir__)

    around do |example|
      Dir.mktmpdir("tsykvas-install-spec-") do |tmp|
        FileUtils.cp_r("#{fixture}/.", tmp)
        @destination = tmp
        example.run
      end
    end

    def run_generator(args = [])
      described_class.start(args, destination_root: @destination, shell: Thor::Shell::Basic.new)
    end

    def read(rel)
      File.read(File.join(@destination, rel))
    end

    it "does not duplicate `include Pundit::Authorization` on re-run" do
      run_generator(%w[--skip-claude])
      first_run = read("app/controllers/application_controller.rb")

      run_generator(%w[--skip-claude --force])
      second_run = read("app/controllers/application_controller.rb")

      expect(second_run.scan(/include Pundit::Authorization/).count).to eq(1)
      expect(first_run.scan(/include Pundit::Authorization/).count).to eq(1)
    end

    it "does not duplicate `include OperationsMethods` on re-run" do
      run_generator(%w[--skip-claude])
      run_generator(%w[--skip-claude --force])

      ac = read("app/controllers/application_controller.rb")
      expect(ac.scan(/include OperationsMethods/).count).to eq(1)
    end

    it "does not append a second `config.autoload_paths` line on re-run" do
      run_generator(%w[--skip-claude])
      run_generator(%w[--skip-claude --force])

      app_rb = read("config/application.rb")
      autoload_lines = app_rb.scan(%r{config\.autoload_paths\s*\+=.*app/concepts})
      expect(autoload_lines.count).to eq(1)
    end

    it "preserves a hand-edited ApplicationPolicy on re-run" do
      run_generator(%w[--skip-claude])
      hand_edited = read("app/policies/application_policy.rb").sub(
        "class ApplicationPolicy",
        "# user added a comment\nclass ApplicationPolicy"
      )
      File.write(File.join(@destination, "app/policies/application_policy.rb"), hand_edited)

      run_generator(%w[--skip-claude --force])

      expect(read("app/policies/application_policy.rb")).to include("# user added a comment")
    end
  end
end
