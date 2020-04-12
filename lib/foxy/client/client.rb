# frozen_string_literal: true

require "faraday"
require "faraday_middleware"
require "multi_json"

# # require "patron"
# require "typhoeus"

require "middleware"

module Foxy
  module Client
    class Client
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

      class FormRequestMiddleware
        def initialize(app)
          @app = app
        end

        def call(opts)
          if opts[:form]
            opts[:headers][:content_type] = "application/x-www-form-urlencoded"
            opts[:body] = URI.encode_www_form(opts[:form])
          end
          @app.(opts)
        end
      end

      class JsonRequestMiddleware
        def initialize(app)
          @app = app
        end

        def call(opts)
          if opts[:json]
            opts[:headers][:content_type] = "application/json"
            opts[:body] = MultiJson.dump(opts[:json])
          end
          @app.(opts)
        end
      end

      def self.config
        @config ||=
          Foxy::Client::StackHash.new(
            Foxy::Client::Utils.try_first(superclass, :config) ||
              Foxy::Client::Utils.recursive_hash({})
          )
      end

      def self.headers
        @headers ||=
          Foxy::Client::StackHash.new(
            Foxy::Client::Utils.try_first(superclass, :headers) ||
              {}
          )
      end

      def self.params
        @params ||=
          Foxy::Client::StackHash.new(
            Foxy::Client::Utils.try_first(superclass, :params) ||
              Foxy::Client::Utils.recursive_hash({})
          )
      end

      def initialize(headers: {}, params: {}, **kwargs)
        @headers = Foxy::Client::StackHash.new(self.class.headers, headers)
        @params = Foxy::Client::StackHash.new(self.class.params, params)
        @config = Foxy::Client::StackHash.new(self.class.config, kwargs)
      end

      def request(**params)
        backend.(**build_request(**params))
      end

      def build_request(headers: {}, params: {}, **kwargs)
        headers = Foxy::Client::StackHash.new(@headers, headers).to_h
        params = Foxy::Client::StackHash.new(@params, params).to_h
        config = Foxy::Client::StackHash.new(@config, kwargs).to_h

        preprocessors.(**config, headers: headers, params: params)
      end

      def preprocessors
        @preprocessors ||= Middleware::Builder.new do |b|
          b.use(JsonRequestMiddleware)
          b.use(FormRequestMiddleware)
          b.use(XRequestIdMiddleware)
        end
      end

      def connection
        @connection ||= Faraday.new
      end

      def backend
        @backend ||= lambda do |method: :get, url: "http:/", path:, body: nil, headers: nil, params: nil, **_|
          path = Faraday::Utils.URI(url).merge(path)

          connection.public_send(method, path) do |req|
            req.params = params if params
            req.body = body if body
            req.headers = headers if headers
          end
        end
      end
    end
  end
end
