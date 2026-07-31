# frozen_string_literal: true

module Ask
  module Rails
    module Harness
      class Persistence < ::Ask::State::Adapter
        def initialize(model_class: nil)
          @model_class = model_class
        end

        # State::Adapter contract — set/get/delete
        # (aliased through save/load for backward compatibility)

        def set(key, value, ttl: nil)
          save(key, value)
        end

        def get(key)
          load(key)
        end

        def delete(session_id)
          model_class.where(session_id: session_id).delete_all
        end

        # Backward-compatible interface (used by old code and list queries)

        def save(session_id, data)
          record = model_class.find_or_initialize_by(session_id: session_id)
          record.update!(data: data)
        end

        def load(session_id)
          record = model_class.find_by(session_id: session_id)
          record&.data
        end

        def clear
          model_class.delete_all
        end

        def list
          model_class.pluck(:session_id)
        end

        private

        def model_class
          @model_class || Ask::Rails::Harness::Session
        end
      end
    end
  end
end
