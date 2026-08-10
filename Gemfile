source "https://rubygems.org"

gemspec

# Local monorepo path gems for development (the gemspec dependency resolves
# from rubygems for consumers).
gem "ask-ruby-harness", path: "../ask-ruby-harness"

group :test do
  gem "minitest", "~> 5.25"
  gem "mocha", "~> 3.1"
  gem "rake", "~> 13.0"
  gem "faraday", "~> 2.0"
  gem "faraday-multipart"
  gem "base64"
  gem "ask-state-providers"
end
