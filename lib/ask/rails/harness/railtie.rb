# frozen_string_literal: true

module Ask
  module Rails
    module Harness
      class Railtie < ::Rails::Railtie
        rake_tasks do
          desc "Prune old sessions and audit logs based on configuration limits"
          task ask_rails_harness: :cleanup do
            count = Ask::Rails::Harness.cleanup!
            puts "Cleaned up #{count || 0} sessions."
          end
        end

        generators do
          require_relative "../../../generators/ask/rails/harness/install/install_generator"
        end

        initializer "ask_rails_harness.configure" do |app|
          Ask::Rails::Harness.configuration.default_model ||= ENV["ASK_DEFAULT_MODEL"] || "gpt-4o"
          Ask::Rails::Harness.configuration.max_turns ||= (ENV["ASK_MAX_TURNS"] || 25).to_i
        end

        initializer "ask_rails_harness.discover_tools", after: :eager_load_most do
          Ask::Rails::Harness.discover_tools!
        end

        initializer "ask_rails_harness.discover_services", after: :eager_load_most do
          Ask::Rails::Harness::ServiceDiscovery.discover!
        end
      end
    end
  end
end
