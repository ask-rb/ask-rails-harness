# frozen_string_literal: true

module Ask
  module Rails
    module Harness
      class Tool < Ask::Tool
        def rails_root
          ::Rails.root
        end

        # Override call to add audit logging around every tool execution.
        # Logs the intent (sanitized params) and outcome (status, timing),
        # but not the returned data.
        def call(args = {}, abort_controller = nil)
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = super
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

          AuditLog.log(
            session_id: Thread.current[:ask_session_id],
            tool_name: name,
            params: args,
            result: result,
            duration_ms: duration_ms
          )

          result
        end

        # Allow the session to set its ID for audit log correlation.
        # Called by the agent loop before executing a tool.
        def self.session_id=(id)
          Thread.current[:ask_session_id] = id
        end

        def self.session_id
          Thread.current[:ask_session_id]
        end
      end
    end
  end
end
