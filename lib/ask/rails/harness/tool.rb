# frozen_string_literal: true

module Ask
  module Rails
    module Harness
      # The Rails edition's tool base. app_root is pinned to ::Rails.root by
      # the railtie; everything else (audit logging, session correlation)
      # comes from the generic ask-ruby-harness base.
      class Tool < Ask::Ruby::Harness::Tool
      end
    end
  end
end
