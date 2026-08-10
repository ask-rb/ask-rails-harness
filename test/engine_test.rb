# frozen_string_literal: true

require_relative "test_helper"

class EngineTest < Minitest::Test
  def test_ask_rails_module_exists
    assert_kind_of Module, Ask::Rails::Harness
  end

  def test_engine_file_exists
    engine_path = File.expand_path("../lib/ask/rails/harness/engine.rb", __dir__)
    assert File.exist?(engine_path), "Engine file should exist"
  end

  def test_railtie_file_exists
    railtie_path = File.expand_path("../lib/ask/rails/harness/railtie.rb", __dir__)
    assert File.exist?(railtie_path), "Railtie file should exist"
  end

  def test_engine_configures_generators
    engine_path = File.expand_path("../lib/ask/rails/harness/engine.rb", __dir__)
    content = File.read(engine_path)
    assert_includes content, "isolate_namespace"
    assert_includes content, "isolate_namespace"
  end

  def test_railtie_configures_rails
    railtie_path = File.expand_path("../lib/ask/rails/harness/railtie.rb", __dir__)
    content = File.read(railtie_path)
    assert_includes content, "Railtie"
  end

  def test_configuration_is_aliased_to_the_generic_harness
    assert_equal Ask::Ruby::Harness::Configuration, Ask::Rails::Harness::Configuration
    config = Ask::Rails::Harness::Configuration.new
    assert_equal "gpt-4o", config.default_model
    assert_equal 25, config.max_turns
  end

  def test_ask_rails_module_responds_to_version
    assert Ask::Rails::Harness.const_defined?(:VERSION)
  end
end
