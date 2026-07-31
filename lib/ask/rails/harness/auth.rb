# frozen_string_literal: true

module Ask
  module Rails
    module Harness
      # Inclusion module for authenticating the admin chat.
      #
      # By default, all ask-rails-harness engine routes are accessible without auth.
      # To protect them, define a +current_user+ method and set the auth
      # check in an initializer:
      #
      #   Ask::Rails::Harness::Auth.check = -> {
      #     redirect_to main_app.login_path unless current_user&.admin?
      #   }
      #
      # The proc is evaluated in the controller context, so +redirect_to+,
      # +current_user+, +session+, etc. are all available.
      module Auth
        mattr_accessor :check
        self.check = nil
      end
    end
  end
end
