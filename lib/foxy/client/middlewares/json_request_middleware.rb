# frozen_string_literal: true

module Foxy
  module Client
    class JsonRequestMiddleware
      def initialize(app)
        @app = app
      end

      def call(opts)
        if opts[:json]
          opts[:headers]["Content-Type"] = "application/json"
          opts[:body] = MultiJson.dump(opts[:json])
        end
        @app.(opts)
      end
    end
  end
end
