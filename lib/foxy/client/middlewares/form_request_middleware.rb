# frozen_string_literal: true

module Foxy
  module Client
    class FormRequestMiddleware
      def initialize(app)
        @app = app
      end

      def call(opts)
        if opts[:form]
          opts[:headers]["Content-Type"] = "application/x-www-form-urlencoded"
          opts[:body] = URI.encode_www_form(opts[:form])
        end
        @app.(opts)
      end
    end
  end
end
