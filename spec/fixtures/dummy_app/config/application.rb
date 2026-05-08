# frozen_string_literal: true

require_relative "boot"
require "rails/all"

module DummyApp
  class Application < Rails::Application
    config.load_defaults 8.0
    config.autoload_paths += %W[#{config.root}/app/concepts]
  end
end
