Ask::Rails::Harness.configure do |config|
  config.default_model = ENV.fetch("ASK_DEFAULT_MODEL", "gpt-4o")
  config.max_turns = ENV.fetch("ASK_MAX_TURNS", 25).to_i
  config.persistence_adapter = Ask::Rails::Harness::Persistence.new
end
