# frozen_string_literal: true

module Foxy
  module Client
    class XRequestIdMiddleware
      def initialize(app)
        @app = app
      end

      def call(opts)
        execution = Thread.current[:request_id]
        opts[:headers]["X-Request-Id"] ||= execution if execution
        @app.(opts)
      end
    end
  end
end
