# frozen_string_literal: true

require "rails/generators/base"

module TsykvasRailsTemplate
  module Generators
    class ConceptGenerator < ::Rails::Generators::Base
      argument :concept_name,
               type: :string,
               banner: "ConceptName"

      source_root File.expand_path("templates", __dir__)

      desc <<~DESC
        Scaffold a new concept under app/concepts/<path>/{operation,component}/.

        Examples:
          rails g tsykvas_rails_template:concept Crm::Property
          rails g tsykvas_rails_template:concept Property --controller
          rails g tsykvas_rails_template:concept Admin::User --actions index show
      DESC

      class_option :actions,
                   type: :array,
                   default: %w[index show new create edit update destroy],
                   desc: "Subset of CRUD actions to generate"

      class_option :controller,
                   type: :boolean,
                   default: false,
                   desc: "Also generate a thin controller"

      VALID_CONCEPT_NAME = %r{\A[A-Za-z][A-Za-z0-9]*(?:(?:::|/)[A-Za-z][A-Za-z0-9]*)*\z}

      def validate_concept_name
        name = concept_name.to_s.strip

        if name.empty?
          raise ::Thor::Error,
                "concept name is required (e.g. 'Crm::Property' or 'crm/property')"
        end

        if name.start_with?("::") || name.start_with?("/")
          raise ::Thor::Error,
                "concept name '#{name}' must not start with '::' or '/'"
        end

        return if name.match?(VALID_CONCEPT_NAME)

        raise ::Thor::Error,
              "concept name '#{name}' has invalid characters " \
              "(allowed: letters, digits, '::' or '/' separators; " \
              "each segment must start with a letter)"
      end

      def generate_operations
        actions.each do |action|
          template "operation/#{action}.rb.tt",
                   "app/concepts/#{path}/operation/#{action}.rb"
        end
      end

      def generate_components
        component_actions.each do |action|
          template "component/#{action}.rb.tt",
                   "app/concepts/#{path}/component/#{action}.rb"
          template "component/#{action}.html.slim.tt",
                   "app/concepts/#{path}/component/#{action}.html.slim"
        end
      end

      def generate_controller
        return unless options[:controller]

        template "controller.rb.tt",
                 "app/controllers/#{controller_file_path}.rb"
      end

      def announce_next_steps
        say ""
        say "  Concept #{class_name} scaffolded.", :green
        say "    - operations: app/concepts/#{path}/operation/"
        say "    - components: app/concepts/#{path}/component/"
        say "    - controller: app/controllers/#{controller_file_path}.rb" if options[:controller]
        say "    Add routes for #{plural_var.tr("_", " ")} in config/routes.rb."
        say "    Implement the policy at app/policies/#{singular_var}_policy.rb."
        say ""
      end

      private

      def actions
        options[:actions]
      end

      def component_actions
        actions & %w[index show new edit]
      end

      def class_name
        @class_name ||= concept_name.split(%r{::|/}).reject(&:empty?).map(&:camelize).join("::")
      end

      def path
        @path ||= class_name.gsub("::", "/").underscore
      end

      def singular_var
        @singular_var ||= path.split("/").last
      end

      def plural_var
        @plural_var ||= singular_var.pluralize
      end

      def resource_class
        @resource_class ||= class_name.split("::").last
      end

      def i18n_key
        @i18n_key ||= path.tr("/", ".")
      end

      def controller_class_name
        parts = class_name.split("::")
        parts[-1] = parts.last.pluralize
        "#{parts.join("::")}Controller"
      end

      def controller_file_path
        pieces = path.split("/")
        pieces[-1] = pieces.last.pluralize
        "#{pieces.join("/")}_controller"
      end

      def url_helper_singular
        path.tr("/", "_")
      end

      def url_helper_plural
        url_helper_singular.sub(/#{Regexp.escape(singular_var)}\z/, plural_var)
      end
    end
  end
end
