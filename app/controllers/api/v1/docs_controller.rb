module Api
  module V1
    # Serves the machine-readable OpenAPI description of the public API at
    # /api/v1/openapi.json. Deliberately unauthenticated (no BaseController):
    # it describes the contract, exposes no data, and integrating tools need
    # to fetch it before they have a token. docs/openapi.yaml is canonical.
    class DocsController < ActionController::API
      def openapi
        expires_in 1.hour, public: true
        render json: self.class.spec
      end

      def self.spec
        @spec ||= YAML.safe_load_file(Rails.root.join("docs/openapi.yaml"))
      end
    end
  end
end
