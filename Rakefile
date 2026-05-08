# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

desc "Audit Gemfile.lock against the public ruby-advisory-db for known CVEs"
task :audit do
  sh "bundle exec bundle-audit check --update"
end

task default: %i[spec rubocop]
