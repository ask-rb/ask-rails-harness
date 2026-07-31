# frozen_string_literal: true

require_relative "test_helper"

class EnvironmentPermissionsTest < Minitest::Test
  def setup
    @env = Ask::Rails::Harness::EnvironmentPermissions.new
  end

  def test_defaults_are_nil
    assert_nil @env.mode
    assert_nil @env.allowed_commands
    assert_nil @env.denied_commands
  end

  def test_mode_is_settable
    @env.mode = :read_only
    assert_equal :read_only, @env.mode
  end

  def test_allowed_commands_is_settable
    @env.allowed_commands = [/^rails /]
    assert_equal 1, @env.allowed_commands.size
    assert @env.allowed_commands.first.match?("rails routes")
  end

  def test_denied_commands_is_settable
    @env.denied_commands = [/rm /, /dropdb/]
    assert_equal 2, @env.denied_commands.size
  end

  def test_configured_via_config_block
    Ask::Rails::Harness.configuration.environment :staging do |env|
      env.mode = :ask_before_changes
      env.allowed_commands = [/^rails /]
      env.denied_commands = [/rm /]
    end

    env_config = Ask::Rails::Harness.configuration.environments[:staging]
    assert_equal :ask_before_changes, env_config.mode
    assert_equal [/^rails /], env_config.allowed_commands
    assert_equal [/rm /], env_config.denied_commands
  end
end
