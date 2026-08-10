## [0.2.0] — 2026-08-10

### Added

- **`run_tests` tool** — runs the app's test suite and returns structured
  results (summary counts plus per-test file/line/message for failures)
  instead of raw terminal output. Detects minitest vs rspec (`Gemfile.lock` +
  `spec/`), supports `file:`/`name:` filters, `failed_only:` reruns persisted
  from the previous run (`tmp/test/.ask/last-failures.json`), and a `timeout:`
  that kills the run and reports `timed_out` with the artifact path. Minitest
  gets machine-readable results via a bundled reporter/plugin; rspec uses its
  built-in JSON formatter.
- **`MinitestJsonReporter` + minitest plugin** — `lib/minitest/ask_rails_harness_plugin.rb`
  is auto-discovered by minitest and registers the JSON reporter only when
  `ASK_TEST_JSON_PATH` is set (i.e. when the harness invoked the run), so
  ordinary `bin/rails test` runs are untouched. Supports both the minitest 5
  (`ask_rails_harness_plugin_init`) and minitest 6 (`plugin_ask_rails_harness_init`)
  plugin init conventions. Full human output always lands at
  `tmp/test/.ask/last-test.log`.

### Fixed

- **`ReadLog` crashed with `NoMethodError: undefined method 'env' for module Ask::Rails`** —
  `read_log.rb` used bare `Rails.env`, which resolves lexically to the
  `Ask::Rails` module inside the gem's own namespace. Now `::Rails.env`
  (matching `query_database.rb`).
- **Audit-log failure warnings were silently swallowed** — `audit_log.rb` used
  the same bare-`Rails` lookup, so `defined?(Rails.logger)` was always false.
  Now `::Rails.logger&.warn` with a nil-safe guard.

## [0.1.1] — 2026-07-31

### Changed

- Use `Ask::Agent::Policies::Permissions` for environment hooks (requires
  ask-agent >= 0.28.0).
- Require `time` for time-stdlib methods (`iso8601`, `parse`).

## [0.1.0] — 2026-07-25

### Changed

- **Gem renamed from `ask-rails` to `ask-rails-harness`** — The gem has been renamed to better reflect its purpose as an admin AI copilot harness for Rails apps. The old `ask-rails` gem name has been yanked from rubygems.org to make room for a new `ask-rails` gem with a different purpose.
- **Module namespace moved from `Ask::Rails` to `Ask::Rails::Harness`** — All code now lives under `Ask::Rails::Harness::*` to coexist with the planned `ask-rails` gem.
- **Engine namespace changed** — `isolate_namespace` updated from `Ask::Rails` to `Ask::Rails::Harness`. Route helpers change from `ask_rails.*` to `ask_rails_harness.*`.
- **Generator renamed** — Use `rails generate ask_rails_harness:install` instead of `ask_rails:install`.
- **Initializer renamed** — Generated file is now `config/initializers/ask_rails_harness.rb`.
- **Rake task renamed** — Use `rails ask_rails_harness:cleanup` instead of `ask_rails:cleanup`.
- **Notification name changed** — `audit_log.ask_rails` is now `audit_log.ask_rails_harness`.
- **Log prefix changed** — `[ask-rails]` is now `[ask-rails-harness]`.

### Migration from ask-rails

Existing applications using `ask-rails` should:
1. Replace `gem "ask-rails"` with `gem "ask-rails-harness"` in your Gemfile
2. Update `Ask::Rails.configure` → `Ask::Rails::Harness.configure`
3. Update `mount Ask::Rails::Engine` → `mount Ask::Rails::Harness::Engine`
4. Update `ask_rails.*` route helpers → `ask_rails_harness.*`
5. Update `Ask::Rails::Auth` → `Ask::Rails::Harness::Auth`
6. Rename initializer from `ask_rails.rb` to `ask_rails_harness.rb`

All previous versions (0.1.0–0.11.1) were released under the `ask-rails` gem name. See the [ask-rails CHANGELOG](https://github.com/ask-rb/ask-rails) for history of those releases.
