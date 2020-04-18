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
        session.(**build_request(**params))
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

      def session
        @session ||= lambda do |method: :get, url: "http:/", path:, body: nil, headers: nil, params: nil, **_|
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
