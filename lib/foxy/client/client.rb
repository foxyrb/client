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

      class MultipartRequestMiddleware
        def initialize(app)
          @app = app
        end

        def call(opts)
          if opts[:multipart]
            boundary = generate_boundary
            body = dump(opts[:multipart], boundary)

            opts[:headers]['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
            opts[:headers]['Content-Length'] = body.length.to_s
            opts[:body] = body
          end
          @app.(opts)
        end

        def generate_boundary
          "-----------RubyMultipartPost-#{SecureRandom.hex}"
        end

        def dump(params, boundary)
          parts = process_params(params) do |key, value|
            part(boundary, key, value)
          end
          parts << Faraday::Parts::EpiloguePart.new(boundary)

          Faraday::CompositeReadIO.new(parts)
        end

        def process_params(params, prefix = nil, pieces = nil, &block)
          params.inject(pieces || []) do |all, (key, value)|
            key = "#{prefix}[#{key}]" if prefix

            case value
            when Array
              values = value.inject([]) { |a, v| a << [nil, v] }
              process_params(values, key, all, &block)
            when Hash
              process_params(value, key, all, &block)
            else
              # rubocop:disable Performance/RedundantBlockCall
              all << block.call(key, value)
              # rubocop:enable Performance/RedundantBlockCall
            end
          end
        end

        def part(boundary, key, value)
          if value.respond_to?(:to_part)
            value.to_part(boundary, key)
          else
            Faraday::Parts::Part.new(boundary, key, value)
          end
        end
      end



      class FormRequestMiddleware
        def initialize(app)
          @app = app
        end

        def call(opts)
          if opts[:form]
            opts[:headers]['Content-Type'] = "application/x-www-form-urlencoded"
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
            opts[:headers]['Content-Type'] = "application/json"
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
          b.use(MultipartRequestMiddleware)
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
