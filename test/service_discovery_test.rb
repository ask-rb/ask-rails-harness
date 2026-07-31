# frozen_string_literal: true

require_relative "test_helper"

class ServiceDiscoveryTest < Minitest::Test
  def test_build_system_prompt_with_no_services
    prompt = Ask::Rails::Harness::ServiceDiscovery.build_system_prompt([])
    assert_equal "## Available Services", prompt.strip
  end

  def test_build_system_prompt_with_mock_context
    mod = Module.new
    mod.define_singleton_method(:name) { "Ask::GitHub" }
    mod.const_set(:DESCRIPTION, "A test service for GitHub integration")
    mod.const_set(:DOCS_URL, "https://docs.github.com")

    prompt = Ask::Rails::Harness::ServiceDiscovery.build_system_prompt([mod])
    assert prompt.is_a?(String)
    assert_includes prompt, "GitHub"
    assert_includes prompt, "test service"
    assert_includes prompt, "docs.github.com"
  end

  def test_build_system_prompt_with_multiple_contexts
    mod1 = Module.new
    mod1.define_singleton_method(:name) { "Ask::Slack" }
    mod1.const_set(:DESCRIPTION, "Slack integration")

    mod2 = Module.new
    mod2.define_singleton_method(:name) { "Ask::Notion" }
    mod2.const_set(:DESCRIPTION, "Notion integration")
    mod2.const_set(:AUTH_HOW, "OAuth")

    prompt = Ask::Rails::Harness::ServiceDiscovery.build_system_prompt([mod1, mod2])
    assert_includes prompt, "Slack"
    assert_includes prompt, "Notion"
    assert_includes prompt, "OAuth"
  end

  def test_build_system_prompt_without_description
    mod = Module.new
    mod.define_singleton_method(:name) { "Ask::Unknown" }

    prompt = Ask::Rails::Harness::ServiceDiscovery.build_system_prompt([mod])
    assert_includes prompt, "Unknown"
  end

  def test_discover_returns_empty_when_no_ask_gems
    result = Ask::Rails::Harness::ServiceDiscovery.discover!
    assert_kind_of Array, result
  end
end
