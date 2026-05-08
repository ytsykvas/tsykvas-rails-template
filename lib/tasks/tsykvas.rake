# frozen_string_literal: true

require "json"
require "tsykvas_rails_template/probe"

namespace :tsykvas do
  desc "Print a deterministic JSON inventory of the host project (consumed by /tsykvas-claude)"
  task :probe do
    puts JSON.pretty_generate(TsykvasRailsTemplate::Probe.run)
  end
end
