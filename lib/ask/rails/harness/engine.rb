# frozen_string_literal: true

require_relative "auth"

module Ask
  module Rails
    module Harness
      class Engine < ::Rails::Engine
        isolate_namespace Ask::Rails::Harness
      end
    end
  end
end
