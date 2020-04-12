# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Foxy::Client::StackArray) do
  let(:ary_n1) { described_class.new }
  let(:ary_n2) { described_class.new(ary_n1) }
  let(:ary_n3) { described_class.new(ary_n2) }
  let(:ary_n4) { described_class.new(ary_n3) }

  before do
    ary_n1 << :a
    ary_n3 << :c
    ary_n2 << :b
    ary_n4 << :d
    ary_n3 << :e
  end

  describe "ary_n4" do
    it { expect(ary_n4.to_a).to eq %i[a b c e d] }

    it { expect(ary_n4.each).to be_a(Enumerator) }

    it { expect(ary_n4.each.to_a).to eq %i[a b c e d] }

    it { expect(ary_n4.map(&:to_s)).to eq %w[a b c e d] }
  end

  describe "ary_n2" do
    it { expect(ary_n2.to_a).to eq %i[a b] }

    it { expect(ary_n2.each).to be_a(Enumerator) }

    it { expect(ary_n2.each.to_a).to eq %i[a b] }

    it { expect(ary_n2.map(&:to_s)).to eq %w[a b] }
  end
end
