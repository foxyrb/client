# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Foxy::Client::StackHash) do
  let(:base) { nil }
  let(:hash_n1) { described_class.new(base) }
  let(:hash_n2) { described_class.new(hash_n1) }
  let(:hash_n3) { described_class.new(hash_n2) }
  let(:hash_n4) { described_class.new(hash_n3) }

  before do
    hash_n1[:hkey1] = :a
    hash_n3[:hkey3] = :c
    hash_n2[:hkey2] = :b
    hash_n4[:hkey4] = :d
    hash_n3[:hkey3_b] = :e
  end

  describe "hash_n4" do
    it { expect(hash_n4.to_h).to eq(hkey1: :a, hkey2: :b, hkey3: :c, hkey3_b: :e, hkey4: :d) }

    it { expect(hash_n4[:hkey1]).to eq(:a) }
    it { expect(hash_n4[:hkey2]).to eq(:b) }
    it { expect(hash_n4[:hkey3]).to eq(:c) }
    it { expect(hash_n4[:hkey3_b]).to eq(:e) }
    it { expect(hash_n4[:hkey4]).to eq(:d) }
    it { expect(hash_n4[:hkey5]).to eq(nil) }

    it { expect(hash_n4.fetch(:hkey1)).to eq(:a) }
    it { expect(hash_n4.fetch(:hkey2)).to eq(:b) }
    it { expect(hash_n4.fetch(:hkey3)).to eq(:c) }
    it { expect(hash_n4.fetch(:hkey3_b)).to eq(:e) }
    it { expect(hash_n4.fetch(:hkey4)).to eq(:d) }
    it { expect { hash_n4.fetch(:hkey5) }.to raise_exception(KeyError) }

    it { expect(hash_n4.fetch(:hkey5) { :hkey55 }).to eq(:hkey55) }
  end

  describe "hash_n2" do
    it { expect(hash_n2.to_h).to eq(hkey1: :a, hkey2: :b) }

    it { expect(hash_n2[:hkey1]).to eq(:a) }
    it { expect(hash_n2[:hkey2]).to eq(:b) }
    it { expect(hash_n2[:hkey3]).to eq(nil) }
    it { expect(hash_n2[:hkey4]).to eq(nil) }
    it { expect(hash_n2[:hkey5]).to eq(nil) }

    it { expect(hash_n2.fetch(:hkey1)).to eq(:a) }
    it { expect(hash_n2.fetch(:hkey2)).to eq(:b) }
    it { expect { hash_n2.fetch(:hkey3) }.to raise_exception(KeyError) }
    it { expect { hash_n2.fetch(:hkey4) }.to raise_exception(KeyError) }
    it { expect { hash_n2.fetch(:hkey5) }.to raise_exception(KeyError) }

    it { expect(hash_n2.fetch(:hkey5) { :hkey55 }).to eq(:hkey55) }
  end

  describe "hash_n4 recursive" do
    let(:base) { Foxy::Client::Utils.recursive_hash({}) }

    it { expect(hash_n2.to_h).to eq(hkey1: :a, hkey2: :b) }

    it { expect(hash_n2[:hkey1]).to eq(:a) }
    it { expect(hash_n2[:hkey2]).to eq(:b) }
    it { expect(hash_n2[:hkey3]).to eq({}) }
    it { expect(hash_n2[:hkey4]).to eq({}) }
    it { expect(hash_n2[:hkey5]).to eq({}) }

    it { expect(hash_n2.fetch(:hkey1)).to eq(:a) }
    it { expect(hash_n2.fetch(:hkey2)).to eq(:b) }
    it { expect { hash_n2.fetch(:hkey3) }.to raise_exception(KeyError) }
    it { expect { hash_n2.fetch(:hkey4) }.to raise_exception(KeyError) }
    it { expect { hash_n2.fetch(:hkey5) }.to raise_exception(KeyError) }

    it { expect(hash_n2.fetch(:hkey5) { :hkey55 }).to eq(:hkey55) }
  end

  describe "different childs" do
    describe "param case" do
      let(:config) { described_class.new(Foxy::Client::Utils.recursive_hash({})) }
      let(:c1) { described_class.new(config) }
      let(:c2) { described_class.new(config) }

      before do
        config
        c1[:params][:api_token] = "my-secret-token"
        c2
      end

      it { expect(config.to_h).to eq({}) }
      it { expect(c1.to_h).to eq(params: { api_token: "my-secret-token" }) }
      it { expect(c2.to_h).to eq({}) }
    end

    describe "middlewares case" do
      let(:config) { described_class.new(Foxy::Client::Utils.recursive_hash({})) }
      let(:c1) { described_class.new(config) }
      let(:c2) { described_class.new(config) }

      before do
        config[:mid] = []
        config[:mid] << :req_id
        c1[:mid] << :req_json
        c2[:mid] << :res_json
        config[:mid] << :retry
      end

      it { expect(config.to_h).to eq(mid: %i[req_id retry]) }
      it { expect(c1.to_h).to eq(mid: %i[req_id retry req_json]) }
      it { expect(c2.to_h).to eq(mid: %i[req_id retry res_json]) }
    end

    describe "complex case" do
      let(:config) { described_class.new(Foxy::Client::Utils.recursive_hash({})) }
      let(:c1) { described_class.new(config) }
      let(:c2) { described_class.new(config) }

      before do
        config[:rate_limit] = nil
        config[:user_agent] = nil
        config[:headers][:user_agent] = "UA"
        config[:ssl][:verify] = true
        config[:url] = "http:/"
        config[:mid] = []
        config[:mid] << %i[request request_id]

        c1[:mid] << %i[request json]
        c1[:params][:api_token] = "my-secret-token"

        c2[:url] = "https://httpbin.org"
        c2[:user_agent] = "test-agent"
        c2[:mid] << %i[response json]
      end

      it {
        expect(config.to_h).to eq(
          headers: [[:user_agent, "UA"]],
          mid: [%i[request request_id]],
          rate_limit: nil,
          ssl: [[:verify, true]],
          url: "http:/",
          user_agent: nil
        )
      }

      it {
        expect(c1.to_h).to eq(
          headers: [[:user_agent, "UA"]],
          mid: [%i[request request_id], %i[request json]],
          params: [[:api_token, "my-secret-token"]],
          rate_limit: nil,
          ssl: [[:verify, true]],
          url: "http:/",
          user_agent: nil
        )
      }

      it {
        expect(c2.to_h).to eq(
          headers: [[:user_agent, "UA"]],
          mid: [%i[request request_id], %i[response json]],
          rate_limit: nil,
          ssl: [[:verify, true]],
          url: "https://httpbin.org",
          user_agent: "test-agent"
        )
      }
    end
  end

  describe "to_h" do
    let(:sh) { Foxy::Client::StackHash.method(:new) }
    let(:sa) { Foxy::Client::StackArray.method(:new) }
    let(:str) { "#<SH #<SH {}, {:mid=>[:rid]}>, {:mid=>#<SA #<SA [:rid], []>, [:json]>}>" }
    let(:o) { sh.(sh.({}, mid: [:rid]), mid: sa.(sa.([:rid], []), [:json])) }

    it { expect(o.inspect).to eq str }
    it { expect(o.to_h).to eq mid: %i[rid json] }
  end
end
