# frozen_string_literal: true

require_relative "test_helper"

class PersistenceTest < Minitest::Test
  FakeModel = Struct.new(:session_id, :data, keyword_init: true) do
    def self.records
      @records ||= {}
    end

    def self.find_or_initialize_by(session_id:)
      records[session_id] ||= new(session_id: session_id)
    end

    def self.find_by(session_id:)
      records[session_id]
    end

    def self.where(session_id:)
      @_delete_key = session_id
      self
    end

    def self.delete_all
      records.delete(@_delete_key) if @_delete_key
      @_delete_key = nil
    end

    def self.pluck(column)
      records.values.map { |r| r.public_send(column) }
    end

    def update!(attrs)
      attrs.each { |k, v| send(:"#{k}=", v) }
    end

    def [](key)
      send(key)
    end
  end

  def setup
    FakeModel.records.clear
  end

  def test_persistence_initializes
    p = Ask::Rails::Harness::Persistence.new
    assert p
  end

  def test_model_class_as_constructor_arg
    p = Ask::Rails::Harness::Persistence.new(model_class: FakeModel)
    assert p
  end

  def test_persistence_interface
    p = Ask::Rails::Harness::Persistence.new(model_class: FakeModel)
    # State::Adapter contract
    assert_respond_to p, :set
    assert_respond_to p, :get
    assert_respond_to p, :delete
    # Backward-compatible interface
    assert_respond_to p, :save
    assert_respond_to p, :load
    assert_respond_to p, :list
  end

  def test_set_and_get_roundtrip
    p = Ask::Rails::Harness::Persistence.new(model_class: FakeModel)
    data = { id: "session-1", messages: [{ role: "user", content: "hello" }] }
    p.set("session-1", data)
    result = p.get("session-1")
    assert_equal "session-1", result[:id]
    assert_equal "hello", result[:messages][0][:content]
  end

  def test_get_missing
    p = Ask::Rails::Harness::Persistence.new(model_class: FakeModel)
    assert_nil p.get("nonexistent")
  end

  def test_save_covers_old_interface
    p = Ask::Rails::Harness::Persistence.new(model_class: FakeModel)
    p.save("s1", { messages: ["hello"] })
    loaded = p.load("s1")
    assert_equal "hello", loaded[:messages][0]
  end

  def test_delete_removes
    p = Ask::Rails::Harness::Persistence.new(model_class: FakeModel)
    p.set("k", { v: 1 })
    p.delete("k")
    assert_nil p.get("k")
  end

  def test_lists_sessions
    p = Ask::Rails::Harness::Persistence.new(model_class: FakeModel)
    p.set("a", {})
    p.set("b", {})
    assert_includes p.list, "a"
    assert_includes p.list, "b"
  end

  def test_defaults_to_ask_rails_session_when_available
    unless defined?(Ask::Rails::Harness::Session)
      skip "Ask::Rails::Harness::Session not loaded in test environment"
    end
    p = Ask::Rails::Harness::Persistence.new
    assert_equal Ask::Rails::Harness::Session, p.send(:model_class)
  end
end
