# frozen_string_literal: true

require "json"
require "faraday"

module ProviderAccounts
  class ConnectLichess
    class ConflictError < StandardError; end
    class ProfileFetchError < StandardError; end

    LICHESS_ACCOUNT_URL = "https://lichess.org/api/account"
    LICHESS_EMAIL_URL = "https://lichess.org/api/account/email"

    def self.call(auth:, current_user: nil)
      new(auth:, current_user:).call
    end

    def initialize(auth:, current_user: nil)
      @auth = auth
      @current_user = current_user
    end

    def call
      access_token = @auth.credentials.token
      identity = resolve_identity(access_token)
      provider_user_id = identity.fetch(:provider_user_id)
      username = identity.fetch(:username)
      email = identity[:email]
      token_expires_at = token_expires_at_from(@auth.credentials.expires_at)

      existing_account = ProviderAccount.find_by(provider: :lichess, provider_user_id: provider_user_id)

      if existing_account
        return handle_existing_account(existing_account, username:, access_token:, token_expires_at:)
      end

      if @current_user
        create_provider_account(
          @current_user,
          provider_user_id:,
          username:,
          access_token:,
          token_expires_at:
        )
        return @current_user
      end

      user = find_or_create_user(email:, username:, provider_user_id:)
      create_provider_account(user, provider_user_id:, username:, access_token:, token_expires_at:)
      user
    end

    private

    def resolve_identity(access_token)
      if @auth.info&.username.present? && @auth.uid.present? && @auth.uid != "lichess"
        return {
          provider_user_id: @auth.uid,
          username: @auth.info.username,
          email: @auth.info.email.presence
        }
      end

      account = fetch_account(access_token)
      {
        provider_user_id: account.fetch("id"),
        username: account.fetch("username"),
        email: fetch_email(access_token)
      }
    rescue KeyError, ProfileFetchError => e
      raise ProfileFetchError, "Could not load your Lichess profile: #{e.message}"
    end

    def fetch_account(access_token)
      response = lichess_get(LICHESS_ACCOUNT_URL, access_token)
      raise ProfileFetchError, "account request failed (#{response.status})" unless response.success?

      JSON.parse(response.body)
    end

    def fetch_email(access_token)
      response = lichess_get(LICHESS_EMAIL_URL, access_token)
      return nil unless response.success?

      JSON.parse(response.body)["email"]
    rescue JSON::ParserError
      nil
    end

    def lichess_get(url, access_token)
      Faraday.get(url) do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
      end
    end

    def handle_existing_account(existing_account, username:, access_token:, token_expires_at:)
      if @current_user && existing_account.user_id != @current_user.id
        raise ConflictError
      end

      existing_account.update!(
        provider_username: username,
        access_token: access_token,
        token_expires_at: token_expires_at
      )
      existing_account.user
    end

    def find_or_create_user(email:, username:, provider_user_id:)
      if email.present?
        user = User.find_by(email: email)
        return user if user
      end

      User.create!(
        email: email.presence || "pending-lichess-#{provider_user_id}@placeholder.local",
        username: unique_username(username),
        password: Devise.friendly_token[0, 50],
        confirmed_at: Time.current
      )
    end

    def create_provider_account(user, provider_user_id:, username:, access_token:, token_expires_at:)
      user.provider_accounts.create!(
        provider: :lichess,
        provider_user_id: provider_user_id,
        provider_username: username,
        access_token: access_token,
        token_expires_at: token_expires_at
      )
    end

    def unique_username(base)
      candidate = base.to_s.gsub(/[^a-zA-Z0-9_]/, "_")[0, 30]
      candidate = "lichess_user" if candidate.length < 3
      return candidate unless User.exists?(username: candidate)

      suffix = 1
      loop do
        trimmed = candidate[0, 28]
        trial = "#{trimmed}_#{suffix}"
        return trial unless User.exists?(username: trial)

        suffix += 1
      end
    end

    def token_expires_at_from(expires_at)
      return nil if expires_at.blank?

      Time.zone.at(expires_at)
    end
  end
end
