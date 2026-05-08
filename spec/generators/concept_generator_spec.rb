# frozen_string_literal: true

require "spec_helper"
require "pathname"
require "thor"
require "rails/generators"
require_relative "../../lib/generators/tsykvas_rails_template/concept/concept_generator"

RSpec.describe TsykvasRailsTemplate::Generators::ConceptGenerator do
  let(:templates_dir) { Pathname(described_class.source_root) }

  it "exposes a source_root that exists on disk" do
    expect(templates_dir).to be_directory
  end

  describe "input validation (A4)" do
    let(:generator) { described_class.new([name]) }

    context "with a valid two-segment name" do
      let(:name) { "Crm::Property" }
      it("accepts the input") { expect { generator.validate_concept_name }.not_to raise_error }
    end

    context "with a valid single-segment name" do
      let(:name) { "Property" }
      it("accepts the input") { expect { generator.validate_concept_name }.not_to raise_error }
    end

    context "with a valid path-style name" do
      let(:name) { "crm/property" }
      it("accepts the input") { expect { generator.validate_concept_name }.not_to raise_error }
    end

    context "with a deeply-nested name" do
      let(:name) { "Admin::Billing::Invoice" }
      it("accepts the input") { expect { generator.validate_concept_name }.not_to raise_error }
    end

    context "with an empty string" do
      let(:name) { "" }
      it "raises Thor::Error mentioning the requirement" do
        expect { generator.validate_concept_name }.to raise_error(
          Thor::Error,
          /required/
        )
      end
    end

    context "with whitespace-only input" do
      let(:name) { "   " }
      it "raises Thor::Error" do
        expect { generator.validate_concept_name }.to raise_error(Thor::Error, /required/)
      end
    end

    context "with a leading ::" do
      let(:name) { "::Foo" }
      it "raises Thor::Error" do
        expect { generator.validate_concept_name }.to raise_error(
          Thor::Error,
          /must not start with/
        )
      end
    end

    context "with a leading /" do
      let(:name) { "/foo" }
      it "raises Thor::Error" do
        expect { generator.validate_concept_name }.to raise_error(
          Thor::Error,
          /must not start with/
        )
      end
    end

    context "with invalid characters" do
      let(:name) { "Foo-Bar" }
      it "raises Thor::Error" do
        expect { generator.validate_concept_name }.to raise_error(
          Thor::Error,
          /invalid characters/
        )
      end
    end

    context "with shell metacharacters" do
      let(:name) { "Foo;rm -rf" }
      it "raises Thor::Error" do
        expect { generator.validate_concept_name }.to raise_error(Thor::Error, /invalid/)
      end
    end

    context "with a segment starting with a digit" do
      let(:name) { "Foo::1Bar" }
      it "raises Thor::Error" do
        expect { generator.validate_concept_name }.to raise_error(Thor::Error, /invalid/)
      end
    end
  end

  describe "re-run safety (A5)" do
    let(:source) do
      Pathname(__dir__).parent.parent.join(
        "lib/generators/tsykvas_rails_template/concept/concept_generator.rb"
      ).read
    end

    it "does not pass force: true to template calls (Thor prompts on conflict by default)" do
      # If a template call had `force: true`, re-running the generator would silently
      # overwrite user edits. We want Thor's standard conflict prompt to fire.
      offending = source.scan(/template\s+[^\n]*force:\s*true/)
      expect(offending).to be_empty,
                           "template calls must not use `force: true`: #{offending.inspect}"
    end

    it "does not pass force: true to copy_file calls" do
      offending = source.scan(/copy_file\s+[^\n]*force:\s*true/)
      expect(offending).to be_empty,
                           "copy_file calls must not use `force: true`: #{offending.inspect}"
    end
  end

  describe "shipped templates" do
    %w[index show new create edit update destroy].each do |action|
      it "ships operation/#{action}.rb.tt" do
        expect(templates_dir.join("operation/#{action}.rb.tt")).to be_file
      end
    end

    %w[index show new edit].each do |action|
      it "ships component/#{action}.rb.tt" do
        expect(templates_dir.join("component/#{action}.rb.tt")).to be_file
      end

      it "ships component/#{action}.html.slim.tt" do
        expect(templates_dir.join("component/#{action}.html.slim.tt")).to be_file
      end
    end

    it "ships controller.rb.tt" do
      expect(templates_dir.join("controller.rb.tt")).to be_file
    end
  end

  describe "scaffold quality" do
    let(:create_template) { templates_dir.join("operation/create.rb.tt").read }
    let(:update_template) { templates_dir.join("operation/update.rb.tt").read }

    it "raises NotImplementedError in create scaffold params (no silent zero-permit)" do
      expect(create_template).to include("raise NotImplementedError")
    end

    it "raises NotImplementedError in update scaffold params (no silent zero-permit)" do
      expect(update_template).to include("raise NotImplementedError")
    end

    it "points to .claude/docs/forms.md from the create scaffold" do
      expect(create_template).to include(".claude/docs/forms.md")
    end

    it "points to .claude/docs/forms.md from the update scaffold" do
      expect(update_template).to include(".claude/docs/forms.md")
    end
  end

  describe "generator declares expected actions in Thor invoke order" do
    # Thor invokes commands in the order of `.commands.keys`. Argument accessors
    # (`concept_name`, `concept_name=`) are not commands.
    let(:command_order) { described_class.commands.keys }

    it "lists validate_concept_name as the first command" do
      expect(command_order.first).to eq("validate_concept_name")
    end

    it "runs validate_concept_name before any generation step" do
      generation_steps = %w[generate_operations generate_components generate_controller]
      validate_idx = command_order.index("validate_concept_name")
      first_gen_idx = generation_steps.map { |m| command_order.index(m) }.compact.min

      expect(validate_idx).not_to be_nil
      expect(first_gen_idx).not_to be_nil
      expect(validate_idx).to be < first_gen_idx,
                              "validate_concept_name must run before any generation step. " \
                              "Thor command order: #{command_order.inspect}"
    end
  end

  describe "options" do
    let(:option_names) { described_class.class_options.keys }

    it { expect(option_names).to include(:actions) }
    it { expect(option_names).to include(:controller) }
  end
end
