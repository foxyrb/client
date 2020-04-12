# frozen_string_literal: true

module Foxy
  module Client
    class StackArray
      extend Forwardable
      include Enumerable

      def initialize(stack = nil, current = [])
        @stack = stack || []
        @current = current
      end

      def_delegator :@current, :<<
      def_delegator :to_a, :each

      def to_a
        @stack.to_a + @current
      end

      def as_json
        to_a.as_json
      end

      def deep_clone
        to_a
      end

      def ==(other)
        return false unless other.respond_to?(:to_a)

        to_a == other.to_a
      end

      def inspect
        "#<SA #{@stack}, #{@current}>"
      end

      def to_s
        "#<SA #{@stack.to_a}, #{@current}>"
      end
    end
end
end
