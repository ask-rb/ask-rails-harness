# frozen_string_literal: true

Ask::Rails::Harness::Engine.routes.draw do
  root to: "chat#index"

  resources :sessions, only: [:index, :create, :show], controller: "chat" do
    collection do
      delete :destroy, action: :destroy_all
    end
  end

  delete "sessions/:id" => "chat#destroy_session", as: :session_destroy
  post "sessions/:session_id/messages" => "chat#message", as: :session_message
  get "sessions/:session_id/stream" => "chat#stream", as: :session_stream
  get "sessions/:session_id/messages" => "chat#history", as: :session_history
  get "sessions/:session_id/audit" => "chat#audit", as: :session_audit
end
