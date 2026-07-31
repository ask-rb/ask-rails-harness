# frozen_string_literal: true

module Ask
  module Rails
    module Harness
      module Tools
        class ReadFile < Ask::Rails::Harness::Tool
          description "Read a file from the Rails app. Paths are relative to Rails.root."

          param :path, type: :string, desc: "Relative path from Rails.root", required: true

          def execute(path:)
            full_path = rails_root.join(path)
            return Ask::Result.error(message: "File not found: #{path}") unless full_path.exist?

            content = full_path.read
            { path: path, content: content, size: content.length }
          end
        end
      end
    end
  end
end
