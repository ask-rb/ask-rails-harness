# frozen_string_literal: true

require_relative "test_helper"

class VersionTest < Minitest::Test
  def test_version_is_set
    refute_nil Ask::Rails::Harness::VERSION
    assert_match(/\A\d+\.\d+\.\d+\z/, Ask::Rails::Harness::VERSION)
  end
end
