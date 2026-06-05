# frozen_string_literal: true

module OmniauthHelpers
  def mock_lichess_auth(uid: "lichess-user-1", username: "lichessuser", email: "lichess@example.com", token: "lichess-token")
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:lichess] = OmniAuth::AuthHash.new(
      provider: "lichess",
      uid: uid,
      info: OmniAuth::AuthHash::InfoHash.new(username: username, email: email),
      credentials: OmniAuth::AuthHash.new(token: token, expires_at: 1.year.from_now.to_i)
    )
  end

  def clear_omniauth_mock
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:lichess] = nil
  end
end

RSpec.configure do |config|
  config.include OmniauthHelpers

  config.before do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:lichess] = nil
  end
end
