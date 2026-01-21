# frozen_string_literal: true

require_relative "lib/flow_tracker/version"

Gem::Specification.new do |spec|
  spec.name = "flow_tracker"
  spec.version = FlowTracker::VERSION
  spec.authors = ["Boubacar Diallo"]
  spec.email = ["boubacar@jamaa.co"]

  spec.summary = "Track job and process execution flows with a web dashboard"
  spec.description = "A Ruby gem that tracks Sidekiq/ActiveJob execution flows, providing detailed process tracking with nested flows, log entries, and a Sinatra-based web dashboard for monitoring."
  spec.homepage = "https://github.com/bdiallo/flow_tracker"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem
  spec.files = Dir.chdir(__dir__) do
    Dir["{lib,spec}/**/*", "LICENSE", "README.md", "Rakefile"]
  end
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "activerecord", ">= 6.1"
  spec.add_dependency "activesupport", ">= 6.1"
  spec.add_dependency "sinatra", ">= 3.0"
  spec.add_dependency "rack", ">= 2.0"

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "pg", "~> 1.5"
  spec.add_development_dependency "sqlite3", "~> 2.1"
  spec.add_development_dependency "database_cleaner-active_record", "~> 2.1"
  spec.add_development_dependency "factory_bot", "~> 6.2"
  spec.add_development_dependency "rack-test", "~> 2.1"
end
