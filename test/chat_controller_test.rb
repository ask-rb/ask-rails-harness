# frozen_string_literal: true

require_relative "test_helper"

class ChatControllerTest < Minitest::Test
  def setup
    Ask::ModelCatalog.reset_instance!
    Ask::ModelCatalog.instance.register(Ask::ModelInfo.new(id: "gpt-4o", provider: "openai"))

    @original_auth = Ask::Rails::Harness::Auth.check
    Ask::Rails::Harness::Auth.check = nil
  end

  def teardown
    Ask::Rails::Harness::Auth.check = @original_auth
  end

  def test_engine_is_rails_engine
    assert Ask::Rails::Harness::Engine < ::Rails::Engine
    assert Ask::Rails::Harness::Engine.respond_to?(:isolate_namespace)
  end

  def test_routes_file_exists
    route_file = File.expand_path("../config/routes.rb", __dir__)
    assert File.exist?(route_file), "Routes file should exist at #{route_file}"
  end

  def test_routes_file_has_chat_endpoints
    content = File.read(File.expand_path("../config/routes.rb", __dir__))
    assert_includes content, "sessions"
    assert_includes content, "messages"
    assert_includes content, "stream"
    assert_includes content, "root to:"
    assert_includes content, "chat#index"
  end

  def test_routes_file_uses_engine_namespace
    content = File.read(File.expand_path("../config/routes.rb", __dir__))
    assert_includes content, "Ask::Rails::Harness::Engine.routes.draw"
  end

  def test_auth_module_exists
    assert Ask::Rails::Harness::Auth.respond_to?(:check)
    assert Ask::Rails::Harness::Auth.respond_to?(:check=)
  end

  def test_auth_check_nil_by_default
    assert_nil Ask::Rails::Harness::Auth.check
  end

  def test_auth_check_custom_proc
    called = false
    Ask::Rails::Harness::Auth.check = -> { called = true }
    Ask::Rails::Harness::Auth.check.call
    assert called
  end

  def test_build_agent_session
    session = Ask::Rails::Harness.agent_session
    assert_instance_of Ask::Agent::Session, session
  end

  def test_build_agent_session_with_model
    session = Ask::Rails::Harness.agent_session
    assert_equal "gpt-4o", session.chat.model_id
  end

  def test_configuration_defaults
    config = Ask::Rails::Harness::Configuration.new
    assert_equal "gpt-4o", config.default_model
    assert_equal 25, config.max_turns
    assert_nil config.system_prompt
    assert_nil config.persistence_adapter
  end

  def test_chat_controller_file_exists
    controller_file = File.expand_path("../app/controllers/ask/rails/harness/chat_controller.rb", __dir__)
    assert File.exist?(controller_file)
  end

  def test_chat_view_file_exists
    view_file = File.expand_path("../app/views/ask/rails/harness/chat/index.html.erb", __dir__)
    assert File.exist?(view_file)
  end

  def test_chat_layout_file_exists
    layout_file = File.expand_path("../app/views/layouts/ask/rails/harness/application.html.erb", __dir__)
    assert File.exist?(layout_file)
  end

  def test_controller_source_has_required_actions
    source = File.read(File.expand_path("../app/controllers/ask/rails/harness/chat_controller.rb", __dir__))
    %w[index create message stream history destroy].each do |action|
      assert_includes source, "def #{action}"
    end
  end

  def test_controller_source_has_sse_streaming
    source = File.read(File.expand_path("../app/controllers/ask/rails/harness/chat_controller.rb", __dir__))
    assert_includes source, "text/event-stream"
    assert_includes source, "Enumerator.new"
  end

  def test_controller_source_has_auth
    source = File.read(File.expand_path("../app/controllers/ask/rails/harness/chat_controller.rb", __dir__))
    assert_includes source, "authenticate!"
  end

  def test_view_source_has_chat_ui
    source = File.read(File.expand_path("../app/views/layouts/ask/rails/harness/application.html.erb", __dir__))
    assert_includes source, "sendMessage"
    assert_includes source, "message-input"
    assert_includes source, "session-list"
  end

  def test_rails_module_agent_session
    session = Ask::Rails::Harness.agent_session
    assert_instance_of Ask::Agent::Session, session
  end

  def test_discover_tools_adds_shell_tools
    old_tools = Ask::Rails::Harness.configuration.tools.dup
    Ask::Rails::Harness.discover_tools!
    assert Ask::Rails::Harness.configuration.tools.any?,
           "Should have at least one tool after discovery"
  ensure
    Ask::Rails::Harness.configuration.tools = old_tools
  end
end
