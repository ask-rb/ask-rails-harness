# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"

class ToolsTest < Minitest::Test
  def setup
    @run_command = Ask::Rails::Harness::Tools::RunCommand.new
    @query_database = Ask::Rails::Harness::Tools::QueryDatabase.new
    @read_model = Ask::Rails::Harness::Tools::ReadModel.new
    @read_log = Ask::Rails::Harness::Tools::ReadLog.new
  end

  # --- compat shims: generic tools remain reachable under the Rails namespace

  def test_generic_tools_are_aliased_into_the_rails_namespace
    assert_equal Ask::Ruby::Harness::Tools::RunCommand, Ask::Rails::Harness::Tools::RunCommand
    assert_equal Ask::Ruby::Harness::Tools::QueryDatabase, Ask::Rails::Harness::Tools::QueryDatabase
    assert_equal Ask::Ruby::Harness::Tools::ReadModel, Ask::Rails::Harness::Tools::ReadModel
    assert_equal Ask::Ruby::Harness::Tools::ReadLog, Ask::Rails::Harness::Tools::ReadLog
    assert_equal Ask::Ruby::Harness::Tools::SchemaGraph, Ask::Rails::Harness::Tools::SchemaGraph
    assert_equal Ask::Ruby::Harness::Tools::RunTests, Ask::Rails::Harness::Tools::RunTests
  end

  def test_audit_log_and_configuration_are_aliased
    assert_equal Ask::Ruby::Harness::AuditLog, Ask::Rails::Harness::AuditLog
    assert_equal Ask::Ruby::Harness::Configuration, Ask::Rails::Harness::Configuration
  end

  def test_rails_tool_base_subclasses_the_generic_tool
    assert_operator Ask::Rails::Harness::Tool, :<, Ask::Ruby::Harness::Tool
    assert Ask::Rails::Harness::Tools::RouteInspector.ancestors.include?(Ask::Rails::Harness::Tool)
  end

  def test_core_rails_tools_compose_generic_tools_and_route_inspector
    assert_includes Ask::Rails::Harness::CORE_RAILS_TOOLS, Ask::Ruby::Harness::Tools::RunCommand
    assert_includes Ask::Rails::Harness::CORE_RAILS_TOOLS, Ask::Ruby::Harness::Tools::RunTests
    assert_includes Ask::Rails::Harness::CORE_RAILS_TOOLS, Ask::Rails::Harness::Tools::RouteInspector
  end

  def test_rails_configuration_uses_rails_environment
    with_env("RAILS_ENV" => "staging") do
      config = Ask::Rails::Harness::Configuration.new
      config.environment :staging do |env|
        env.mode = :read_only
      end
      assert_equal :read_only, config.effective_mode
    end
  end

  # --- the permission gate still works through the aliased RunCommand

  def test_run_command_blocked_by_denied_pattern
    original = Ask::Rails::Harness.configuration.denied_commands
    Ask::Rails::Harness.configuration.denied_commands = [/rm -rf/]
    result = @run_command.call(command: "rm -rf /tmp/foo")
    assert_instance_of Ask::Result, result
    assert result.error?
  ensure
    Ask::Rails::Harness.configuration.denied_commands = original
  end

  def test_run_command_deny_takes_precedence_over_allow
    original_allowed = Ask::Rails::Harness.configuration.allowed_commands
    original_denied = Ask::Rails::Harness.configuration.denied_commands
    Ask::Rails::Harness.configuration.allowed_commands = [/rm -rf/]
    Ask::Rails::Harness.configuration.denied_commands = [/rm -rf/]
    result = @run_command.call(command: "rm -rf /tmp/foo")
    assert result.error?
  ensure
    Ask::Rails::Harness.configuration.allowed_commands = original_allowed
    Ask::Rails::Harness.configuration.denied_commands = original_denied
  end

  # --- query/read tools still function against a live database

  def test_query_database_rejects_write_statements
    %w[UPDATE DELETE DROP TRUNCATE ALTER CREATE GRANT REVOKE].each do |stmt|
      result = @query_database.call(sql: "#{stmt} TABLE users")
      assert result.error?, "#{stmt} should be rejected"
    end
  end

  def test_query_database_select_with_live_db
    with_test_db do |_db|
      result = @query_database.call(sql: "SELECT * FROM test_items ORDER BY value ASC")
      assert_instance_of Hash, result, "Expected Hash but got #{result.class}"
      assert_equal %w[id name value], result[:columns]
      assert_equal 5, result[:count]
    end
  end

  def test_read_model_returns_columns
    with_test_model do |model_name|
      result = @read_model.call(name: model_name)
      assert_instance_of Hash, result
      assert result.key?(:columns)
      assert result[:columns].any? { |c| c[:name] == "name" }
    end
  end

  # --- audit instrumentation still fires through the Rails namespace

  def test_tool_call_invokes_audit_log
    Ask::Rails::Harness::Tool.session_id = "test-session-123"

    log_entries = []
    subscriber = ActiveSupport::Notifications.subscribe("audit_log.ask_ruby_harness") do |_name, _start, _finish, _id, payload|
      log_entries << payload
    end

    result = @run_command.call(command: "echo ok")
    assert_instance_of Ask::Result, result

    assert_equal 1, log_entries.length
    assert_equal "run_command", log_entries.first[:tool_name]
    assert_equal "test-session-123", log_entries.first[:session_id]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    Ask::Rails::Harness::Tool.session_id = nil
  end

  private

  def with_env(overrides)
    original = overrides.to_h { |k, _| [k, ENV[k]] }
    overrides.each { |k, v| ENV[k] = v }
    yield
  ensure
    original.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  def with_test_db
    require "active_record"
    Dir.mktmpdir do |dir|
      db_path = File.join(dir, "test.db")
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: db_path)
      ActiveRecord::Base.connection.create_table(:test_items, force: true) do |t|
        t.string :name
        t.integer :value
      end
      (0..4).each do |i|
        ActiveRecord::Base.connection.insert("INSERT INTO test_items (name, value) VALUES ('item_#{i}', #{i * 10})")
      end
      yield ActiveRecord::Base.connection
      ActiveRecord::Base.connection.disconnect!
    end
  end

  def with_test_model
    require "active_record" unless defined?(ActiveRecord::Base)
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Base.connection.create_table(:test_profiles, force: true) do |t|
      t.string :name, null: false
      t.string :email
      t.timestamps
    end

    model = Class.new(ActiveRecord::Base) do
      self.table_name = "test_profiles"
      validates :name, presence: true
      has_many :nonexistent_dummy
    end
    self.class.const_set(:TestProfile, model)
    model.table_name # ensure it loads

    yield "ToolsTest::TestProfile"
  ensure
    self.class.send(:remove_const, :TestProfile) rescue nil
    ActiveRecord::Base.descendants.delete(model) if model && ActiveRecord::Base.descendants.include?(model)
    ActiveRecord::Base.connection.disconnect! if ActiveRecord::Base.connected?
  end
end
