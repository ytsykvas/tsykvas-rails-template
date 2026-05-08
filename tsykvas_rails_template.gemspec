# frozen_string_literal: true

require_relative "lib/tsykvas_rails_template/version"

Gem::Specification.new do |spec|
  spec.name = "tsykvas_rails_template"
  spec.version = TsykvasRailsTemplate::VERSION
  spec.authors = ["Yurii Tsykvas"]
  spec.email = ["tsykvasyurii@gmail.com"]

  spec.summary = "Rails template: thin controllers, Operation/Component architecture, and Claude tooling."
  spec.description = <<~DESC
    Installs an opinionated Rails skeleton: thin `endpoint Operation, Component`
    controllers, plain-Ruby `Base::Operation::Base` + `Result` classes, a
    ViewComponent-based `app/concepts/<feature>/{operation,component}/` layout,
    and a `.claude/` directory pre-loaded with battle-tested slash commands,
    subagents, and architecture docs. Ships generators to scaffold the host app
    and to create new concept directories.
  DESC
  # Assumed GitHub URL based on gem name + author. Verify it matches your actual
  # public repo before `gem push` — RubyGems uses this for the gem's home page.
  spec.homepage = "https://github.com/tsykvas/tsykvas_rails_template"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "pundit", ">= 2.3"
  spec.add_dependency "rails", ">= 7.1"
  spec.add_dependency "slim-rails", ">= 3.6"
  spec.add_dependency "view_component", ">= 3.0"
end
