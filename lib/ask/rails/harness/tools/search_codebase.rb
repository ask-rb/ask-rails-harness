# frozen_string_literal: true

module Ask
  module Rails
    module Harness
      module Tools
        class SearchCodebase < Ask::Rails::Harness::Tool
          description "Search the Rails codebase with grep."
          param :pattern, type: :string, desc: "Search pattern", required: true
          param :path, type: :string, desc: "Subdirectory to search (optional)", required: false

          def execute(pattern:, path: nil)
            search_path = (path ? rails_root.join(path) : rails_root).to_s
            escaped_pattern = pattern.gsub("'", "'\\\\''")
            escaped_path = search_path.gsub("'", "'\\\\''")
            results = `cd #{rails_root} && grep -rn '#{escaped_pattern}' #{escaped_path} 2>&1 | head -50`
            { results: results.lines.map(&:chomp), count: results.lines.count }
          end
        end
      end
    end
  end
end
