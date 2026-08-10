# frozen_string_literal: true

require "rails"
require "ask/ruby/harness"
require "ask/auth"
require "time"

module Ask
  module Rails
    module Harness
      class << self
        # The Rails edition shares the generic configuration — the generic
        # gem owns the runtime, this gem adapts it to Rails.
        def configure
          yield configuration
        end

        def configuration
          Ask::Ruby::Harness.configuration
        end

        def agent_session(**extra)
          Ask::Ruby::Harness.agent_session(**extra)
        end

        def discover_tools!
          Ask::Ruby::Harness.discover_tools!
        end

        def cleanup!
          Ask::Ruby::Harness.cleanup!
        end

        def root
          @root ||= Pathname.new(File.expand_path("../..", __dir__))
        end
      end
    end
  end
end

require_relative "harness/version"
require_relative "harness/engine"
require_relative "harness/auth"
require_relative "harness/persistence"
require_relative "harness/service_discovery"
require_relative "harness/tool"
require_relative "harness/tools" # backward-compat constant aliases
require_relative "harness/tools/route_inspector"

# Railtie is loaded only when Rails is fully available
if defined?(::Rails::Railtie)
  require_relative "harness/railtie"
end

# Define after all tool files are loaded so the constants resolve. The
# generic Rails-aware tools come from ask-ruby-harness; this gem adds the
# Rails-native ones (RouteInspector) on top.
Ask::Rails::Harness::CORE_RAILS_TOOLS = [
  *Ask::Ruby::Harness::HARNESS_TOOLS,
  Ask::Rails::Harness::Tools::RouteInspector
].freeze
