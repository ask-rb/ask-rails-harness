# frozen_string_literal: true

module Ask
  module Rails
    module Harness
      module Tools
        class ReadRoutes < Ask::Rails::Harness::Tool
          description "Read the Rails routes from config/routes.rb"
          def execute
            routes_file = rails_root.join("config", "routes.rb")
            return Ask::Result.error(message: "No routes file found") unless routes_file.exist?

            content = routes_file.read
            { content: content, size: content.length }
          end
        end
      end
    end
  end
end
