# frozen_string_literal: true

require "spec_helper"
require "logger"

require "json"

Thread.new { MockHTTPBinServer.start(false, 5300) }

RSpec.describe(Foxy::Client::Client) do
  let(:adapter) { [:rack, MockHTTPBin] }
  # let(:adapter) { :patron }

  subject { Foxy::Client::Client.new(adapter: adapter, url: "http://localhost:5300", headers: { user_agent: "test-agent" }) }
  # subject { Foxy::Client::Client.new(adapter: adapter, url: "https://httpbin.org", user_agent: "test-agent")

  it "#request / json" do
    response = subject.request(path: "/get")
    json = JSON.parse(response.body)

    expect(json).to match(
      "args" => {},
      "headers" => {
        "Accept" => "*/*",
        "Host" => "localhost:5300",
        "User-Agent" => "test-agent",
        "Content-Length" => nil,
        "Version" => "HTTP/1.1",
        "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
        "X-Request-Id" => EXECUTION
      },
      "origin" => "127.0.0.1",
      "url" => "http://localhost:5300/get"
    )
  end

  it "#json with multiple jsonn params" do
    response = subject.request(method: :post,
                               path: "/post",
                               params: { a: :a, b: :b },
                               json: { b: :b, c: :c },
                               headers: { h: "h" })
    json = JSON.parse(response.body)

    expect(json).to match(
      "args" => {
        "a" => "a",
        "b" => "b"
      },
      "data" => "{\"b\":\"b\",\"c\":\"c\"}",
      "files" => {},
      "form" => {},
      "headers" => {
        "Accept" => "*/*",
        "Content-Length" => "17",
        "Content-Type" => "application/json",
        "H" => "h",
        "Host" => "localhost:5300",
        "User-Agent" => "test-agent",
        "Version" => "HTTP/1.1",
        "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
        "X-Request-Id" => EXECUTION
      },
      "json" => { "b" => "b", "c" => "c" },
      "origin" => "127.0.0.1",
      "url" => "http://localhost:5300/post?a=a&b=b"
    )
  end

  it "#json with multiple form params" do
    response = subject.request(method: :post,
                               path: "/post",
                               params: { a: :a, b: :b },
                               form: { b: :b, c: :c },
                               headers: { h: "h" })
    json = JSON.parse(response.body)

    expect(json).to match(
      "args" => {
        "a" => "a",
        "b" => "b"
      },
      "data" => "",
      "files" => {},
      "form" => { "b" => "b", "c" => "c" },
      "headers" => {
        "Accept" => "*/*",
        "Content-Length" => "7",
        "Content-Type" => "application/x-www-form-urlencoded",
        "H" => "h",
        "Host" => "localhost:5300",
        "User-Agent" => "test-agent",
        "Version" => "HTTP/1.1",
        "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
        "X-Request-Id" => EXECUTION
      },
      "json" => nil,
      "origin" => String, # "127.0.0.1",
      "url" => "http://localhost:5300/post?a=a&b=b"
    )
  end

  it "#json with multiple params and raw body" do
    response = subject.request(method: :post,
                               path: "/post",
                               params: { a: :a, b: :b },
                               body: "this is the plain body",
                               headers: { h: "h", "Content-Type": "text/plain" })
    json = JSON.parse(response.body)

    expect(json).to match(
      "args" => {
        "a" => "a",
        "b" => "b"
      },
      "data" => "this is the plain body",
      "files" => {},
      "form" => {},
      "headers" => {
        "Accept" => "*/*",
        "Content-Length" => "22",
        "Content-Type" => "text/plain",
        "H" => "h",
        "Host" => "localhost:5300",
        "User-Agent" => "test-agent",
        "Version" => "HTTP/1.1",
        "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
        "X-Request-Id" => EXECUTION
      },
      "json" => nil,
      "origin" => String, # "127.0.0.1",
      "url" => "http://localhost:5300/post?a=a&b=b"
    )
  end

  # describe "subclient with monad_result" do
  #   subject do
  #     c = Class.new(Foxy::Client::Client) do
  #       config[:monad_result] = true
  #       # config[:middlewares] << [:response, :monad_response]
  #     end

  #     c.new(adapter: adapter, url: "http://localhost:5300", user_agent: "test-agent")
  #   end

  #   it "monadic responses" do
  #     response = subject.request(method: :post, path: "/get")
  #     expect(response).not_to be_ok
  #     expect(response).to be_error

  #     response = subject.request(method: :get, path: "/get")
  #     expect(response).to be_ok
  #     expect(response).not_to be_error
  #   end
  # end

  describe "subclient with middlewares and api_token" do
    it do
      klass = Class.new(Foxy::Client::Client) do
        # [:request, :token_auth, "secret"]
        headers[:authorization] = "Token token=\"secret\""
        # [:request, :user_agent, app: "MyFoxy", version: "1.1"]
        headers[:user_agent] = Foxy::Client::Utils.user_agent(app: "MyFoxy", version: "1.1")
        headers[:accept] = "application/vnd.widgets-v2+json"
        headers[:x_version_number] = "10"

        # config[:middlewares] << [:use, :repeater, retries: 6, mode: :exponential]

        params[:api_token] = "my-secret-token"
      end

      client = klass.new(adapter: adapter, url: "http://localhost:5300")

      response = client.request(method: :post, path: "/post", json: { key: :value })

      json = JSON.parse(response.body)

      expect(json).to match(
        "args" => { "api_token" => "my-secret-token" },
        "data" => "{\"key\":\"value\"}",
        "files" => {},
        "form" => {},
        "headers" => {
          "Accept" => "application/vnd.widgets-v2+json",
          "Authorization" => "Token token=\"secret\"",
          "Content-Length" => "15",
          "Content-Type" => "application/json",
          "Host" => "localhost:5300",
          "User-Agent" => match(%r{Foxy/1.1 \(.*\) ruby/.*}),
          "Version" => "HTTP/1.1",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "X-Request-Id" => EXECUTION,
          "X-Version-Number" => "10"
        },
        "json" => { "key" => "value" },
        "origin" => "127.0.0.1",
        "url" => "http://localhost:5300/post?api_token=my-secret-token"
      )
    end
  end

  describe "subclient with url_encoded" do
    subject do
      Class.new(Foxy::Client::Client) do
        config[:url] = "http://localhost:5300"

        headers[:user_agent] = "test-agent"
      end.new(adapter: adapter)
    end

    it do
      response = subject.request(method: :post, path: "/post", form: { key: :value })

      json = JSON.parse(response.body)

      expect(json).to match(
        "args" => {},
        "data" => "",
        "files" => {},
        "form" => { "key" => "value" },
        "headers" => {
          "Accept" => "*/*",
          "Content-Length" => "9",
          "Content-Type" => "application/x-www-form-urlencoded",
          "Host" => "localhost:5300",
          "User-Agent" => "test-agent",
          "Version" => "HTTP/1.1",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "X-Request-Id" => EXECUTION
        },
        "json" => nil,
        "origin" => "127.0.0.1",
        "url" => "http://localhost:5300/post"
      )
    end
  end

  describe "subsubclient with api token" do
    it do
      C1 = Class.new(Foxy::Client::Client) do
        params[:api_token] = "my-secret-token"
      end

      D1 = Class.new(C1) do
        params[:api_token2] = "my-secret-token2"
      end

      client = D1.new(adapter: adapter, url: "http://localhost:5300", headers: { user_agent: "test-agent" })

      response = client.request(path: "/get")

      json = JSON.parse(response.body)

      expect(json).to match(
        "args" => { "api_token" => "my-secret-token", "api_token2" => "my-secret-token2" },
        "headers" => {
          "Accept" => "*/*",
          "Content-Length" => nil,
          "Host" => "localhost:5300",
          "User-Agent" => "test-agent",
          "Version" => "HTTP/1.1",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "X-Request-Id" => EXECUTION
        },
        "origin" => String, # "127.0.0.1",
        "url" => "http://localhost:5300/get?api_token=my-secret-token&api_token2=my-secret-token2"
      )
    end
  end

  describe "subclient with multipart" do
    subject do
      Class.new(Foxy::Client::Client) do
        config[:url] = "http://localhost:5300"
        # config[:url] = "https://httpbin.org"

        headers[:user_agent] = "test-agent"

        def connection
          @connection ||= Faraday.new do |conn|
            conn.request(:multipart)
            conn.request(:url_encoded)
          end
        end
      end.new(adapter: adapter)
    end

    let(:body) do
      {
        file: Faraday::UploadIO.new(StringIO.new("hello world"), "text/plain", "filename.txt"),
        key: :value
      }
    end

    let(:encoded_body) do
      hex32 = "[0-9a-f]{32}"
      Regexp.new([
        "-------------RubyMultipartPost-#{hex32}",
        "Content-Disposition: form-data; name=\"file\"; filename=\"filename.txt\"",
        "Content-Length: 11",
        "Content-Type: text/plain",
        "Content-Transfer-Encoding: binary",
        "",
        "hello world",
        "-------------RubyMultipartPost-#{hex32}",
        "Content-Disposition: form-data; name=\"key\"",
        "",
        "value",
        "-------------RubyMultipartPost-#{hex32}--",
        ""
      ].join("\r\n"))
    end

    it do
      response = subject.request(method: :post, path: "/post", body: body)

      json = JSON.parse(response.body)

      expect(json).to match(
        "args" => {},
        "data" => match(encoded_body),
        "files" => { "file" => "hello world" },
        "form" => { "key" => "value" },
        "headers" => {
          "Accept" => "*/*",
          "Content-Length" => "416",
          "Content-Type" => match(%r{^multipart/form-data; boundary=-----------RubyMultipartPost-}),
          "Host" => "localhost:5300",
          "User-Agent" => "test-agent",
          "Version" => "HTTP/1.1",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "X-Request-Id" => EXECUTION
        },
        "json" => nil,
        "origin" => "127.0.0.1",
        "url" => "http://localhost:5300/post"
      )
    end
  end
end
