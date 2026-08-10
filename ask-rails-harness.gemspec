require_relative "lib/ask/rails/harness/version"

Gem::Specification.new do |spec|
  spec.name = "ask-rails-harness"
  spec.version = Ask::Rails::Harness::VERSION
  spec.authors = ["Kaka Ruto"]
  spec.email = ["kaka@myrrlabs.com"]

  spec.summary = "Admin AI copilot for Rails apps — inspect code, query DB, read logs, debug"
  spec.description = "Rails Engine that mounts an admin AI agent at /ask. Ships Rails-aware tools (QueryDatabase, ReadModel, ReadLog, RunCommand, SchemaGraph, RouteInspector, RunTests), session persistence, audit logging, environment permissions, and service gem discovery. Previously developed as ask-rails (0.1.0–0.11.1)."
  spec.homepage = "https://github.com/ask-rb/ask-rails-harness"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "app/**/*", "config/**/*", "LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.1"
  spec.add_dependency "ask-ruby-harness", ">= 0.1"
  spec.add_dependency "ask-auth", ">= 0.1"

  spec.add_development_dependency "sqlite3", ">= 2.0"
  spec.add_development_dependency "minitest", "~> 5.25"
  spec.add_development_dependency "mocha", "~> 3.1"
  spec.add_development_dependency "rake", "~> 13.0"
end
