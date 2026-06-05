# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/omniauth/strategies/lichess")

RSpec.describe OmniAuth::Strategies::Lichess do
  subject(:strategy) { described_class.new(nil, "test-client-id") }

  describe "#callback_url" do
    it "returns the callback path without the request query string" do
      allow(strategy).to receive_messages(
        full_host: "http://example.com",
        callback_path: "/users/auth/lichess/callback",
        request: instance_double(Rack::Request, query_string: "code=abc&state=xyz")
      )

      expect(strategy.callback_url).to eq("http://example.com/users/auth/lichess/callback")
      expect(strategy.callback_url).not_to include("code=")
      expect(strategy.callback_url).not_to include("state=")
    end
  end
end
