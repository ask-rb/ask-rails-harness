# frozen_string_literal: true

require "rails/generators"

module Ask
  module Rails
    module Harness
      module Generators
        class InstallGenerator < ::Rails::Generators::Base
          source_root File.expand_path("templates", __dir__)

          desc "Creates ask-rails-harness configuration and migration"

          def create_initializer
            template "initializer.rb", "config/initializers/ask_rails_harness.rb"
          end

          def create_migration
            timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
            template "migration.rb", "db/migrate/#{timestamp}_create_ask_sessions.rb"
          end

          def create_audit_log_migration
            timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
            template "audit_log_migration.rb", "db/migrate/#{timestamp}_create_ask_audit_logs.rb"
          end

          def create_tools_directory
            empty_directory "app/tools"
            create_file "app/tools/.keep", ""
          end
        end
      end
    end
  end
end
