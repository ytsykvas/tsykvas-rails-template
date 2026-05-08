# frozen_string_literal: true

require "rails/railtie"

module TsykvasRailsTemplate
  class Railtie < ::Rails::Railtie
    railtie_name :tsykvas_rails_template

    rake_tasks do
      load File.expand_path("../tasks/tsykvas.rake", __dir__)
    end
  end
end
