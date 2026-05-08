# frozen_string_literal: true

require_relative "tsykvas_rails_template/version"
require_relative "tsykvas_rails_template/probe"

# Eager-require runtime deps so the host's `Bundler.require` (which only loads
# gems listed directly in its Gemfile) still picks them up transitively. Without
# this, `include Pundit::Authorization` and the ViewComponent/Slim references
# blow up at boot inside the host app.
require "pundit"
require "view_component"
require "slim-rails"

module TsykvasRailsTemplate
  class Error < StandardError; end
end

require_relative "tsykvas_rails_template/railtie" if defined?(::Rails::Railtie)
