# frozen_string_literal: true

# Backward-compatible constant aliases: the generic tools moved to
# ask-ruby-harness (Ask::Ruby::Harness::Tools::*). Existing references to
# Ask::Rails::Harness::Tools::*, AuditLog, and Configuration keep working.
# (MinitestJsonReporter is intentionally not aliased — it lives behind the
# minitest plugin and must not load minitest at app boot.)
module Ask
  module Rails
    module Harness
      Configuration = Ask::Ruby::Harness::Configuration
      AuditLog = Ask::Ruby::Harness::AuditLog

      module Tools
        RunCommand = Ask::Ruby::Harness::Tools::RunCommand
        QueryDatabase = Ask::Ruby::Harness::Tools::QueryDatabase
        ReadModel = Ask::Ruby::Harness::Tools::ReadModel
        ReadLog = Ask::Ruby::Harness::Tools::ReadLog
        SchemaGraph = Ask::Ruby::Harness::Tools::SchemaGraph
        RunTests = Ask::Ruby::Harness::Tools::RunTests
      end
    end
  end
end
