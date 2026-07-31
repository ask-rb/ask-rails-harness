# frozen_string_literal: true

module Ask
  module Rails
    module Harness
      module Tools
        class RouteInspector < Ask::Rails::Harness::Tool
          description "Return the parsed Rails route table — every route with its HTTP verb, path, " \
                       "controller, action, and name. Returns structured data the agent can filter " \
                       "and reason about, unlike reading the raw routes.rb file."

          param :controller, type: :string, desc: "Filter by controller name (e.g. 'users', 'api/v1/posts')", required: false
          param :pattern, type: :string, desc: "Filter by path pattern (e.g. 'users', 'admin')", required: false
          param :verbose, type: :boolean, desc: "Include internal route details (default false)", required: false

          def execute(controller: nil, pattern: nil, verbose: false)
            return { routes: [], count: 0 } unless defined?(::Rails) && ::Rails.application&.routes

            all_routes = ::Rails.application.routes.routes.map do |route|
              entry = {
                verb: verb_for(route),
                path: route.path.spec.to_s.delete_suffix("(.:format)"),
                controller: route.defaults[:controller]&.to_s,
                action: route.defaults[:action]&.to_s,
                name: route.name&.to_s
              }

              if verbose
                entry[:requirements] = route.required_parts.presence
                entry[:defaults] = route.defaults.except(:controller, :action).presence
                entry[:constraints] = route.constraints.except(:request_method).presence if route.constraints.any?
              end

              entry
            end

            # Remove internal/engine routes unless verbose
            unless verbose
              all_routes.reject! { |r| r[:controller].nil? || r[:controller].start_with?("rails/") }
            end

            # Apply filters
            all_routes.select! { |r| r[:controller] == controller } if controller
            all_routes.select! { |r| r[:path].include?(pattern) } if pattern

            {
              routes: all_routes,
              count: all_routes.size
            }
          end

          private

          def verb_for(route)
            if route.verb.is_a?(String)
              route.verb
            elsif route.verb.respond_to?(:call)
              # Rails stores verb as a regexp — extract the source
              source = route.verb.source
              source.gsub(/[$^\\]/, "").split("|")
            else
              "ANY"
            end
          rescue
            "ANY"
          end
        end
      end
    end
  end
end
