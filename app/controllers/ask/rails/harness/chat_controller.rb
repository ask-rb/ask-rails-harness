# frozen_string_literal: true

require "json"

module Ask
  module Rails
    module Harness
      class ChatController < ::ActionController::Base
        layout "ask/rails/harness/application"

        before_action :authenticate!, unless: -> { Ask::Rails::Harness::Auth.check.nil? }
        before_action :set_session, only: [:message, :stream, :history, :show, :audit]

        # GET /ask — main chat interface
        def index
          @sessions = load_sessions
          @active_session = @sessions.first
          @audit_logs = load_recent_audit_logs
          render :index
        end

        # POST /ask/sessions — create a new session
        def create
          session_id = SecureRandom.uuid

          agent = build_agent_session
          agent.save

          store_session_metadata(session_id, agent)

          redirect_to ask_rails_harness.root_path
        end

        # GET /ask/sessions/:id — show a specific session
        def show
          @messages = load_session_messages(@session_id)
          @audit_logs = load_session_audit_logs(@session_id)
          render json: { id: @session_id, messages: @messages, audit_logs: @audit_logs }
        end

        # GET /ask/sessions — list all sessions
        def index_sessions
          @sessions = load_sessions
          render json: @sessions
        end

        # POST /ask/sessions/:session_id/messages — send a message, get SSE stream
        def message
          prompt = params[:message].to_s.strip
          return head :bad_request if prompt.empty?

          response.headers["Content-Type"] = "text/event-stream"
          response.headers["Cache-Control"] = "no-cache"
          response.headers["X-Accel-Buffering"] = "no"
          response.headers["Last-Modified"] = Time.now.httpdate

          self.response_body = Enumerator.new do |yielder|
            agent = resume_or_create_session(@session_id)

            # Subscribe to tool execution events
            tool_sub = subscribe_tool_events(agent, yielder)

            yielder << "data: #{JSON.generate(type: 'start', session_id: @session_id)}\n\n"

            begin
              agent.run(prompt) do |chunk|
                if chunk.content&.length&.> 0
                  yielder << "data: #{JSON.generate(type: 'delta', content: chunk.content)}\n\n"
                end
                if chunk.thinking&.length&.> 0
                  yielder << "data: #{JSON.generate(type: 'thinking', content: chunk.thinking)}\n\n"
                end
              end

              agent.save
              @session = agent

              yielder << "data: #{JSON.generate(type: 'done', session_id: @session_id)}\n\n"
            rescue Ask::Agent::MaxTurnsExceeded => e
              yielder << "data: #{JSON.generate(type: 'error', message: "Agent hit the turn limit (#{e.message})")}\n\n"
            rescue Ask::Auth::MissingCredential => e
              yielder << "data: #{JSON.generate(type: 'error', message: "Missing API key: #{e.message}. Check your provider configuration.")}\n\n"
            rescue Ask::Auth::InvalidCredential => e
              yielder << "data: #{JSON.generate(type: 'error', message: "Invalid API key: #{e.message}. Update your credentials.")}\n\n"
            rescue StandardError => e
              yielder << "data: #{JSON.generate(type: 'error', message: "Agent error: #{e.message}")}\n\n"
            end
          ensure
            agent&.remove_event_subscriber(tool_sub) if tool_sub
          end
        end

        # GET /ask/sessions/:session_id/stream — SSE stream for an existing session
        def stream
          response.headers["Content-Type"] = "text/event-stream"
          response.headers["Cache-Control"] = "no-cache"
          response.headers["X-Accel-Buffering"] = "no"

          self.response_body = Enumerator.new do |yielder|
            messages = load_session_messages(@session_id)
            audit_logs = load_session_audit_logs(@session_id)
            yielder << "data: #{JSON.generate(type: 'history', messages: messages, audit_logs: audit_logs)}\n\n"

            sleep 30
            yielder << "data: #{JSON.generate(type: 'keepalive')}\n\n"
          end
        end

        # GET /ask/sessions/:session_id/messages — get message history as JSON
        def history
          messages = load_session_messages(@session_id)
          render json: messages
        end

        # GET /ask/sessions/:session_id/audit — get audit logs for a session
        def audit
          logs = load_session_audit_logs(@session_id)
          render json: logs
        end

        # DELETE /ask/sessions — destroy all sessions
        def destroy_all
          persistence = Ask::Rails::Harness.configuration.persistence_adapter
          if persistence
            persistence.list.each { |id| persistence.delete(id) }
          end
          redirect_to ask_rails_harness.root_path
        end

        # DELETE /ask/sessions/:session_id — destroy a specific session
        def destroy_session
          persistence = Ask::Rails::Harness.configuration.persistence_adapter
          persistence&.delete(params[:session_id])
          redirect_to ask_rails_harness.root_path
        end

        private

        def authenticate!
          instance_eval(&Ask::Rails::Harness::Auth.check) if Ask::Rails::Harness::Auth.check
        end

        def set_session
          @session_id = params[:session_id] || params[:id]
          head :not_found unless @session_id
        end

        def build_agent_session(**extra)
          Ask::Rails::Harness.agent_session(**extra)
        end

        def subscribe_tool_events(agent, yielder)
          return nil unless agent.respond_to?(:on_event)

          agent.on_event do |event|
            case event
            when Ask::Agent::Events::ToolExecutionStart
              yielder << "data: #{JSON.generate(
                type: 'tool_start',
                name: event.name,
                id: event.id,
                args: safe_tool_args(event.arguments)
              )}\n\n"
            when Ask::Agent::Events::ToolExecutionEnd
              yielder << "data: #{JSON.generate(
                type: 'tool_end',
                name: event.name,
                id: event.id,
                duration_ms: event.duration_ms,
                is_error: event.is_error
              )}\n\n"
            when Ask::Agent::Events::ToolExecutionUpdate
              yielder << "data: #{JSON.generate(
                type: 'tool_update',
                id: event.id,
                content: event.partial_result.to_s.truncate(200)
              )}\n\n"
            end
          end
        end

        def safe_tool_args(args)
          return {} unless args.is_a?(Hash)

          safe = args.dup
          %w[password secret token api_key key auth_token access_token sql command].each do |sensitive|
            safe[sensitive] = "[REDACTED]" if safe.key?(sensitive)
          end
          safe
        end

        def resume_or_create_session(session_id)
          persistence = Ask::Rails::Harness.configuration.persistence_adapter

          if persistence
            data = persistence.load(session_id)
            if data
              session = Ask::Agent::Session.load(session_id, adapter: persistence)
              return session if session
            end
          end

          Ask::Rails::Harness.agent_session(persistence: persistence).tap do |s|
            s.instance_variable_set(:@id, session_id)
          end
        end

        def load_sessions
          persistence = Ask::Rails::Harness.configuration.persistence_adapter
          return [] unless persistence

          persistence.list.map do |id|
            data = persistence.load(id) || {}
            messages = data[:messages] || []
            { id: id, created_at: data.dig(:metadata, :created_at), message_count: messages.length, preview: messages.first&.dig(:content).to_s.truncate(60) }
          end.sort_by { |s| s[:created_at] || "" }.reverse
        end

        def load_session_messages(session_id)
          persistence = Ask::Rails::Harness.configuration.persistence_adapter
          return [] unless persistence

          data = persistence.load(session_id)
          return [] unless data

          (data[:messages] || []).map { |m|
            { role: m[:role], content: m[:content].to_s }
          }
        end

        def load_session_audit_logs(session_id)
          return [] unless defined?(ActiveRecord::Base)

          ActiveRecord::Base.connection.execute(
            "SELECT tool_name, status, duration_ms, environment, recorded_at, " \
            "params, result_summary, error_message, user_context " \
            "FROM ask_audit_logs WHERE session_id = #{ActiveRecord::Base.connection.quote(session_id.to_s)} " \
            "ORDER BY recorded_at ASC"
          ).map do |row|
            {
              tool_name: row["tool_name"],
              status: row["status"],
              duration_ms: row["duration_ms"],
              environment: row["environment"],
              recorded_at: row["recorded_at"],
              params: parse_json_field(row["params"]),
              result_summary: parse_json_field(row["result_summary"]),
              error_message: row["error_message"],
              user_context: parse_json_field(row["user_context"])
            }
          end
        rescue StandardError
          []
        end

        def load_recent_audit_logs
          return [] unless defined?(ActiveRecord::Base)

          ActiveRecord::Base.connection.execute(
            "SELECT session_id, tool_name, status, duration_ms, recorded_at " \
            "FROM ask_audit_logs ORDER BY recorded_at DESC LIMIT 100"
          ).map do |row|
            {
              session_id: row["session_id"].to_s[0..7],
              tool_name: row["tool_name"],
              status: row["status"],
              duration_ms: row["duration_ms"],
              recorded_at: row["recorded_at"]
            }
          end
        rescue StandardError
          []
        end

        def parse_json_field(value)
          return nil unless value
          return value if value.is_a?(Hash) || value.is_a?(Array)
          JSON.parse(value)
        rescue JSON::ParserError
          value
        end

        def store_session_metadata(session_id, agent)
          persistence = Ask::Rails::Harness.configuration.persistence_adapter
          return unless persistence

          persistence.save(session_id, {
            id: session_id,
            messages: agent.messages.map { |m|
              { role: m.role, content: m.content.to_s }
            },
            metadata: {
              model: ask_rails_harness_model,
              created_at: Time.now.iso8601,
              updated_at: Time.now.iso8601
            }
          })
        end

        def ask_rails_harness_model
          Ask::Rails::Harness.configuration.default_model
        end

        def tool_events_supported?
          defined?(Ask::Agent::Events::ToolExecutionStart)
        end
      end
    end
  end
end
