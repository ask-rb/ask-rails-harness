# frozen_string_literal: true

require_relative "test_helper"

class ConfigurationTest < Minitest::Test
  def test_default_values
    config = Ask::Rails::Harness::Configuration.new
    assert_equal "gpt-4o", config.default_model
    assert_equal 25, config.max_turns
    assert_nil config.system_prompt
    assert_equal 5, config.tool_concurrency
    assert_equal [], config.tools
  end

  def test_defaults_are_mutable
    config = Ask::Rails::Harness::Configuration.new
    config.default_model = "claude-sonnet-4"
    assert_equal "claude-sonnet-4", config.default_model
  end

  def test_tools_are_settable
    config = Ask::Rails::Harness::Configuration.new
    config.tools = [:tool1, :tool2]
    assert_equal [:tool1, :tool2], config.tools
  end

  def test_max_turns_settable
    config = Ask::Rails::Harness::Configuration.new
    config.max_turns = 100
    assert_equal 100, config.max_turns
  end

  def test_system_prompt_settable
    config = Ask::Rails::Harness::Configuration.new
    config.system_prompt = "You are a helpful assistant"
    assert_equal "You are a helpful assistant", config.system_prompt
  end

  def test_persistence_adapter_settable
    config = Ask::Rails::Harness::Configuration.new
    config.persistence_adapter = :memory
    assert_equal :memory, config.persistence_adapter
  end

  def test_tool_concurrency_settable
    config = Ask::Rails::Harness::Configuration.new
    config.tool_concurrency = 10
    assert_equal 10, config.tool_concurrency
  end

  def test_current_user_defaults_to_nil
    config = Ask::Rails::Harness::Configuration.new
    assert_nil config.current_user
  end

  def test_current_user_settable
    config = Ask::Rails::Harness::Configuration.new
    config.current_user = -> { { id: 1 } }
    assert_equal 1, config.current_user.call[:id]
  end

  def test_max_session_age_defaults_to_nil
    config = Ask::Rails::Harness::Configuration.new
    assert_nil config.max_session_age
  end

  def test_max_session_age_settable
    config = Ask::Rails::Harness::Configuration.new
    config.max_session_age = 86400
    assert_equal 86400, config.max_session_age
  end

  def test_max_sessions_defaults_to_nil
    config = Ask::Rails::Harness::Configuration.new
    assert_nil config.max_sessions
  end

  def test_max_sessions_settable
    config = Ask::Rails::Harness::Configuration.new
    config.max_sessions = 100
    assert_equal 100, config.max_sessions
  end

  def test_environment_builder
    config = Ask::Rails::Harness::Configuration.new
    config.environment :production do |env|
      env.mode = :read_only
      env.allowed_commands = [/^rails /]
    end
    assert config.environments.key?(:production)
    assert_equal :read_only, config.environments[:production].mode
  end

  def test_effective_allowed_commands_uses_global_when_no_env_match
    config = Ask::Rails::Harness::Configuration.new
    config.allowed_commands = [/^echo /]
    assert_equal config.allowed_commands, config.effective_allowed_commands
  end

  def test_effective_denied_commands_uses_global_when_no_env_match
    config = Ask::Rails::Harness::Configuration.new
    config.denied_commands = [/rm/]
    assert_equal config.denied_commands, config.effective_denied_commands
  end

  def test_effective_mode_returns_nil_when_no_env_match
    config = Ask::Rails::Harness::Configuration.new
    assert_nil config.effective_mode
  end

  def test_environment_defaults_remain_nil
    config = Ask::Rails::Harness::Configuration.new
    config.environment(:production) { |e| }
    assert_nil config.environments[:production].mode
    assert_nil config.environments[:production].allowed_commands
    assert_nil config.environments[:production].denied_commands
  end
end
