# ask-rails-harness

[![Gem Version](https://badge.fury.io/rb/ask-rails-harness.svg)](https://badge.fury.io/rb/ask-rails-harness)

Admin AI copilot for Rails apps. Mounts a Rails Engine at `/ask` with an admin chat UI and 9 Rails-aware tools that inspect your code, query your database, read logs, and help you debug. For internal/admin use only: the agent has direct access to your database, file system, and shell.

Previously released as `ask-rails` (v0.1.0-0.11.1) and renamed to `ask-rails-harness`. For customer-facing agents, use [ask-agent](https://github.com/ask-rb/ask-agent) directly.

## Installation

```bash
bundle add ask-rails-harness
rails generate ask_rails_harness:install
```

The generator creates `config/initializers/ask_rails_harness.rb`, the `ask_sessions` and `ask_audit_logs` migrations, and an `app/tools/` directory. Requires Rails 7.1+.

Run the migration, then mount the engine in `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  authenticate :user, ->(u) { u.admin? } do
    mount Ask::Rails::Harness::Engine, at: "/ask"
  end
end
```

Visit `/ask` in your browser.

## Quick Start

```ruby
# From any controller, view, or job
session = Ask::Rails::Harness.agent_session
session.run("Find all open issues labeled 'bug' in our repo")
```

## Configuration

```ruby
# config/initializers/ask_rails_harness.rb
Ask::Rails::Harness.configure do |c|
  c.default_model = "claude-sonnet-4"
  c.max_turns = 50
  c.tool_concurrency = 5
  c.allowed_commands = [/^rails /]
  c.denied_commands = [/rm/, /dropdb/]
  c.max_session_age = 7.days
  c.max_sessions = 100
  c.environment :production do |env|
    env.mode = :read_only
  end
end
```

Available settings: `default_model`, `max_turns`, `tool_concurrency`, `system_prompt`, `persistence_adapter`, `current_user`, `allowed_commands`, `denied_commands`, `max_session_age`, `max_sessions`, and per-environment permissions via `environment(name) { |env| env.mode = ... }`.

## Essential API

- `Ask::Rails::Harness.agent_session`: build an agent session with the configured tools and prompt
- `Ask::Rails::Harness.configure { |c| ... }`: configuration (see above)
- `Ask::Rails::Harness.cleanup!`: prune old sessions and audit logs; also available as `rails ask_rails_harness:cleanup`
- `Ask::Rails::Harness::Persistence`: ActiveRecord session persistence backed by the `ask_sessions` table
- `Ask::Rails::Harness::Auth.check = -> { ... }`: auth proc evaluated in the controller context; the engine routes are unprotected by default
- Audit log: every tool call is recorded in `ask_audit_logs` and broadcast as the `audit_log.ask_rails_harness` ActiveSupport notification

## Tools

| Tool | What it does |
|---|---|
| `QueryDatabase` | Read-only SQL (non-SELECT rejected in production) |
| `ReadModel` | Inspect an ActiveRecord model's columns, associations, validations |
| `ReadLog` | Read log files with level/search filtering |
| `RunCommand` | Run shell commands in the app root, gated by permission rules |
| `SchemaGraph` | Full schema introspection: models, tables, columns, associations |
| `RouteInspector` | Parsed route table with filters |
| `RunTests` | Structured test results with failure reruns (minitest/rspec) |

Generic file and search capabilities (read, grep, edit) are provided by the
agent's native tools; the harness focuses on what only a Rails-aware layer
can give an agent: database access, schema/model introspection, routes,
logs, and tests — all permission-gated and audited.

## Full documentation

The full ask-rb documentation lives at https://ask-rb.github.io/ask-docs. [Rails setup](https://ask-rb.github.io/ask-docs/rails/setup) covers ask-rails-harness in depth. API reference: https://ask-rb.github.io/ask-docs/reference/api.

## Development

```bash
bundle install
bundle exec rake test
```

## License

MIT
