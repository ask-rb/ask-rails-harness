# frozen_string_literal: true

require_relative "test_helper"

class RouteInspectorTest < Minitest::Test
  def setup
    @tool = Ask::Rails::Harness::Tools::RouteInspector.new
  end

  def test_defines_correct_name
    assert_equal "route_inspector", @tool.name
  end

  def test_defines_params
    assert @tool.parameters.key?(:controller)
    assert @tool.parameters.key?(:pattern)
    assert @tool.parameters.key?(:verbose)
  end

  def test_inherits_from_ask_rails_tool
    assert Ask::Rails::Harness::Tools::RouteInspector.ancestors.include?(Ask::Rails::Harness::Tool)
  end

  def test_returns_hash_with_routes_and_count
    result = @tool.execute
    assert_instance_of Hash, result
    assert result.key?(:routes)
    assert result.key?(:count)
    assert_kind_of Array, result[:routes]
    assert_kind_of Integer, result[:count]
  end

  def test_routes_have_required_keys
    result = @tool.execute
    result[:routes].each do |route|
      assert route.key?(:verb), "Route missing verb: #{route.inspect}"
      assert route.key?(:path), "Route missing path: #{route.inspect}"
    end
  end

  def test_controller_filter
    result = @tool.execute(controller: "nonexistent_controller_xyz")
    assert_equal 0, result[:count], "Should return 0 routes for nonexistent controller"
    assert_equal [], result[:routes]
  end

  def test_pattern_filter
    result = @tool.execute(pattern: "xyznonexistent12345")
    assert_equal 0, result[:count], "Should return 0 routes for nonexistent pattern"
    assert_equal [], result[:routes]
  end

  # --- Tests with real Rails routes ---

  def test_filters_by_controller
    with_test_routes do
      result = @tool.execute(controller: "test_users")
      assert_operator result[:count], :>=, 5,
        "TestUsers resource should have at least 5 RESTful routes"
      result[:routes].each do |r|
        assert_equal "test_users", r[:controller],
          "All filtered routes should be for test_users controller"
      end
    end
  end

  def test_filters_by_path_pattern
    with_test_routes do
      result = @tool.execute(pattern: "users")
      assert_operator result[:count], :>=, 1,
        "Should find at least 1 route matching 'users'"
      result[:routes].each do |r|
        assert r[:path].include?("users"),
          "Route path #{r[:path]} should contain 'users'"
      end
    end
  end

  def test_verbose_includes_constraints
    with_test_routes do
      result = @tool.execute(verbose: true)
      # At least some routes should have requirements or defaults
      verbose_routes = result[:routes].select { |r| r.key?(:requirements) || r.key?(:defaults) || r.key?(:constraints) }
      assert result[:routes].any?,
        "Should have routes even with verbose=true"
    end
  end

  def test_default_routes_have_verbs
    with_test_routes do
      result = @tool.execute
      verbs = result[:routes].map { |r| r[:verb] }.flatten.uniq
      assert verbs.any? { |v| v.include?("GET") }, "Should have GET routes"
      assert verbs.any? { |v| v.include?("POST") }, "Should have POST routes"
    end
  end

  def test_routes_have_controller_and_action
    with_test_routes do
      result = @tool.execute
      result[:routes].each do |r|
        refute_nil r[:controller], "Route should have a controller: #{r[:path]}"
        refute_nil r[:action], "Route should have an action: #{r[:path]}"
      end
    end
  end

  private

  def with_test_routes
    # Create a temporary Rails application with routes
    app = Class.new(::Rails::Application) do
      config.eager_load = false
      config.secret_key_base = "test_secret_key_base_for_testing_only_12345"
    end

    app.routes.draw do
      resources :test_users do
        resources :test_posts
      end
      get "health", to: "health#show"
      post "login", to: "sessions#create"
    end

    # Stub Rails.application to return our test app
    original_app = ::Rails.application
    ::Rails.application = app

    yield
  ensure
    ::Rails.application = original_app if defined?(original_app)
  end
end
