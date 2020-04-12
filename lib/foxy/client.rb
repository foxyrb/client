# frozen_string_literal: true

require "foxy/client/version"

module Foxy
  module Client
    class Error < StandardError; end
    # Your code goes here...
  end
end

Dir["#{__dir__}/client/**/*.rb"]
  .sort
  .each { |file| require file }
