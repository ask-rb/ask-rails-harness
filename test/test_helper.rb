if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
    add_filter "/vendor/"
    track_files "lib/**/*.rb"
  end
end

# frozen_string_literal: true

# Load paths for local ask-rb gems (prefer local over installed gems)
ask_rb_root = File.expand_path("../..", __dir__)
%w[ask-core ask-tools ask-tools-shell ask-schema ask-skills ask-auth ask-instrumentation ask-llm-providers ask-agent ask-rails-harness ask-sandbox-providers].each do |gem|
  lib = File.join(ask_rb_root, gem, "lib")
  $LOAD_PATH.unshift lib if File.directory?(lib)
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Load required gems before activating bundler's gem paths
require "rails"
require "ask"
require "ask-schema"
require "ask/tools/tool"
require "ask/tools/shell"
require "ask/result"

require "ask/rails/harness"
require "ask/rails/harness/audit_log"
require "ask/rails/harness/environment_permissions"
require "ask/rails/harness/tool"
require "ask/rails/harness/tools/read_file"
require "ask/rails/harness/tools/run_command"
require "ask/rails/harness/tools/search_codebase"
require "ask/rails/harness/tools/read_routes"
require "ask/rails/harness/tools/query_database"
require "ask/rails/harness/tools/read_model"
require "ask/rails/harness/tools/read_log"
require "ask/rails/harness/tools/schema_graph"
require "ask/rails/harness/tools/route_inspector"
require "ask/rails/harness/service_discovery"

require "minitest/autorun"
require "mocha/minitest"

# Stub a minimal Rails environment for tools that need it
module Rails
  class << self
    def root
      Pathname.new("/tmp")
    end

    def env
      @env ||= ActiveSupport::StringInquirer.new("test")
    end

    def env=(environment)
      @env = ActiveSupport::StringInquirer.new(environment.to_s)
    end
  end
end
