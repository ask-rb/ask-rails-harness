# frozen_string_literal: true

module Ask
  module Rails
    module Harness
      module ServiceDiscovery
        SERVICE_GEMS_PATTERN = /\Aask-(?!tools|tools-shell|agent|rails|core|auth|schema|llm)/

        module_function

        def discover!
          service_gems = Gem.loaded_specs.keys.select { |name| name.match?(SERVICE_GEMS_PATTERN) }
          contexts = []

          service_gems.each do |name|
            begin
              require "#{name.tr("-", "/")}/context"
              mod = name.split("-").map(&:capitalize).join.constantize
              contexts << mod if mod.respond_to?(:const_defined?) && mod.const_defined?(:DESCRIPTION)
            rescue LoadError, NameError
            end
          end

          unless contexts.empty?
            prompt = build_system_prompt(contexts)
            existing = Ask::Rails::Harness.configuration.system_prompt
            Ask::Rails::Harness.configuration.system_prompt = [existing, prompt].compact.join("\n\n")
          end

          contexts
        end

        def build_system_prompt(contexts)
          sections = ["## Available Services"]

          contexts.each do |mod|
            name = mod.respond_to?(:name) ? mod.name.to_s.split("::").last || "Unknown" : "Unknown"
            sections << "### #{name}"
            sections << mod::DESCRIPTION if mod.const_defined?(:DESCRIPTION)
            sections << "Documentation: #{mod::DOCS_URL}" if mod.const_defined?(:DOCS_URL)
            sections << "Authentication: #{mod::AUTH_HOW}" if mod.const_defined?(:AUTH_HOW)
            sections << ""
          end

          sections.join("\n")
        end
      end
    end
  end
end
