# frozen_string_literal: true

RSpec.describe(Foxy::Client) do
  it "has a version number" do
    expect(Foxy::Client::VERSION).not_to be nil
  end
end
