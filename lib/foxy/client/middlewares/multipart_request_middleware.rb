# frozen_string_literal: true

module Foxy
  module Client
    class MultipartRequestMiddleware
      def initialize(app)
        @app = app
      end

      def call(opts)
        if opts[:multipart]
          boundary = generate_boundary
          body = dump(opts[:multipart], boundary)

          opts[:headers]["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
          opts[:headers]["Content-Length"] = body.length.to_s
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
            all << block.(key, value)

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
  end
end
