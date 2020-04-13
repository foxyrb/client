# frozen_string_literal: true

require "multi_json"
require "oj"

class MockHTTPBin
  attr_reader :env

  def self.call(env)
    new(env).()
  end

  def initialize(env)
    @env = env
  end

  def call
    case env["PATH_INFO"]
    when "/get"
      get? ? ok_response : error_405
    when "/post"
      post? ? ok_response : error_405
    else
      error_404
    end
  end

  private

  def get?
    env["REQUEST_METHOD"] == "GET"
  end

  def post?
    env["REQUEST_METHOD"] == "POST"
  end

  def headerfy(k)
    k.downcase[5..-1].split("_").map(&:capitalize).join("-")
  end

  def headers
    headers = env
              .select { |k, _v| k.start_with?("HTTP_") }
              .map { |k, v| [headerfy(k), v] }
    headers << ["Content-Type", content_type] if content_type
    headers << ["Content-Length", env["CONTENT_LENGTH"]] if env["CONTENT_LENGTH"] != "0"
    headers << ["Accept", "*/*"]
    headers = headers.sort.to_h
    headers.delete("Cookie") if headers["Cookie"] == ""
    headers
  end

  def content_type
    env["CONTENT_TYPE"]
  end

  def form?
    content_type == "application/x-www-form-urlencoded"
  end

  def json?
    content_type == "application/json"
  end

  def multipart?
    content_type =~ %r{multipart/form-data}
  end

  def url
    query_string = env["QUERY_STRING"] == "" ? "" : "?#{env['QUERY_STRING']}"
    "#{env['rack.url_scheme']}://#{env['HTTP_HOST']}#{env['PATH_INFO']}#{query_string}"
  end

  def body
    @body ||= env["rack.input"].read
  end

  def origin
    env["REMOTE_ADDR"]
  end

  def args
    Rack::Utils.parse_nested_query(env["QUERY_STRING"])
  end

  def body_payload
    if body == ""
      {}
    elsif json?
      { data: body, files: {}, form: {}, json: MultiJson.load(body) }
    elsif form?
      { data: "", files: {}, form: Rack::Utils.parse_nested_query(body), json: nil }
    elsif multipart?
      multipart = Rack::Multipart.parse_multipart(env)
      files, form = multipart.partition { |_k, v| v.is_a?(Hash) }
      files = files.map { |k, v| [k, v[:tempfile].read] }

      { data: body, files: files.to_h, form: form.to_h, json: nil }
    else
      { data: body, files: {}, form: {}, json: nil }
    end
  end

  def ok_response
    payload = body_payload.merge(args: args, headers: headers, origin: origin, url: url)

    ["200", { "Content-Type" => "application/json" }, [MultiJson.dump(payload)]]
    ["200", { "Content-Type" => "text/plain" }, [MultiJson.dump(payload)]]
  end

  def error_404
    ["404", { "Content-Type" => "application/json" }, [MultiJson.dump({})]]
  end

  def error_405
    ["405", { "Content-Type" => "application/json" }, "{}"]
  end
end

# frozen_string_literal: true

require "thin"

STDOUT.sync = true

class MockHTTPBinServer < Thin::Server
  class << self
    # attr_reader :last_request
    # attr_accessor :last_requests

    # def last_request=(req)
    #   @last_request = req
    #   @last_requests ||= []
    #   @last_requests = @last_requests.push(req).last(5)
    # end
  end

  def initialize(silent, *args)
    super(*args, lambda do |env|
      # req = Rack::Request.new(env)
      MockHTTPBin.(env)
    end)

    self.silent = true if silent
  end
end

MockHTTPBinServer.start(false, ENV["PORT"] || 5300) if $PROGRAM_NAME == __FILE__
