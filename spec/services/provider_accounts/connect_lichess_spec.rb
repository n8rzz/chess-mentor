# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProviderAccounts::ConnectLichess do
  let(:auth_hash) do
    OmniAuth::AuthHash.new(
      provider: "lichess",
      uid: "lichess-uid-1",
      info: OmniAuth::AuthHash::InfoHash.new(username: "lichessplayer", email: "player@lichess.org"),
      credentials: OmniAuth::AuthHash.new(token: "access-token", expires_at: 1.year.from_now.to_i)
    )
  end

  describe ".call" do
    context "when signed out and the Lichess account is new" do
      it "creates a user and provider account" do
        expect do
          described_class.call(auth: auth_hash)
        end.to change(User, :count).by(1)
          .and change(ProviderAccount, :count).by(1)

        user = User.last
        account = user.lichess_account

        expect(user.username).to eq("lichessplayer")
        expect(user.email).to eq("player@lichess.org")
        expect(user).to be_confirmed
        expect(account.provider_user_id).to eq("lichess-uid-1")
        expect(account.access_token).to eq("access-token")
      end

      it "uses a placeholder email when Lichess does not return one" do
        auth_hash.info.email = nil

        user = described_class.call(auth: auth_hash)

        expect(user.email).to eq("pending-lichess-lichess-uid-1@placeholder.local")
      end
    end

    context "when signed out and the Lichess account already exists" do
      it "signs in the existing user and refreshes the token" do
        user = create(:user, email: "player@lichess.org")
        account = create(:provider_account, user: user, provider_user_id: "lichess-uid-1", access_token: "old-token")

        result = described_class.call(auth: auth_hash)

        expect(result).to eq(user)
        expect(account.reload.access_token).to eq("access-token")
      end
    end

    context "when signed in and the user has no Lichess link" do
      it "links the provider account without creating a new user" do
        user = create(:user)

        expect do
          described_class.call(auth: auth_hash, current_user: user)
        end.to change(ProviderAccount, :count).by(1)
          .and change(User, :count).by(0)

        expect(user.lichess_account.provider_user_id).to eq("lichess-uid-1")
      end
    end

    context "when the Lichess account belongs to another user" do
      it "raises a conflict error" do
        other_user = create(:user)
        create(:provider_account, user: other_user, provider_user_id: "lichess-uid-1")
        current_user = create(:user)

        expect do
          described_class.call(auth: auth_hash, current_user: current_user)
        end.to raise_error(ProviderAccounts::ConnectLichess::ConflictError)
      end
    end

    context "when auth info is not provided" do
      let(:auth_hash) do
        OmniAuth::AuthHash.new(
          provider: "lichess",
          uid: "lichess",
          info: OmniAuth::AuthHash::InfoHash.new,
          credentials: OmniAuth::AuthHash.new(token: "access-token", expires_at: 1.year.from_now.to_i)
        )
      end

      before do
        account_response = instance_double(
          Faraday::Response,
          success?: true,
          body: { id: "lichess-uid-api", username: "lichessplayer" }.to_json
        )
        email_response = instance_double(
          Faraday::Response,
          success?: true,
          body: { email: "player@lichess.org" }.to_json
        )

        allow(Faraday).to receive(:get) do |url, &block|
          request = double(headers: {})
          block&.call(request)

          case url
          when described_class::LICHESS_ACCOUNT_URL
            account_response
          when described_class::LICHESS_EMAIL_URL
            email_response
          end
        end
      end

      it "fetches profile data from the Lichess API" do
        expect do
          described_class.call(auth: auth_hash)
        end.to change(User, :count).by(1)
          .and change(ProviderAccount, :count).by(1)

        user = User.last
        account = user.lichess_account

        expect(user.username).to eq("lichessplayer")
        expect(user.email).to eq("player@lichess.org")
        expect(account.provider_user_id).to eq("lichess-uid-api")
        expect(account.access_token).to eq("access-token")
      end
    end

    context "when the Lichess username is already taken" do
      it "appends a numeric suffix to create a unique username" do
        create(:user, username: "lichessplayer")

        user = described_class.call(auth: auth_hash)

        expect(user.username).to eq("lichessplayer_1")
      end
    end
  end
end
