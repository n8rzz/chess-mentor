# frozen_string_literal: true

require "json"
require "omniauth-oauth2"

module OmniAuth
  module Strategies
    class Lichess < OmniAuth::Strategies::OAuth2
      PKCE_CACHE_PREFIX = "lichess_pkce"
      PKCE_CACHE_TTL = 10.minutes

      option :name, "lichess"
      option :pkce, true
      option :skip_info, true

      option :client_options,
             site: "https://lichess.org",
             authorize_url: "https://lichess.org/oauth",
             token_url: "https://lichess.org/api/token",
             auth_scheme: :request_body

      uid { "lichess" }

      # OmniAuth appends request.query_string during the callback phase, which breaks
      # Lichess token exchange (redirect_uri must match the authorize request exactly).
      def callback_url
        full_host + callback_path
      end

      def authorize_params
        params = super
        if options.pkce && options.pkce_verifier.present? && params[:state].present?
          Rails.cache.write(pkce_cache_key(params[:state]), options.pkce_verifier, expires_in: PKCE_CACHE_TTL)
        end
        params
      end

      def build_access_token
        code_verifier = session.delete("omniauth.pkce.verifier")
        code_verifier ||= Rails.cache.delete(pkce_cache_key(request.params["state"]))

        if code_verifier.blank?
          raise ::OAuth2::Error, {
            "error" => "missing_code_verifier",
            "error_description" => "PKCE verifier missing from session"
          }
        end

        response = Faraday.post(
          "https://lichess.org/api/token",
          {
            grant_type: "authorization_code",
            code: request.params["code"],
            redirect_uri: callback_url,
            client_id: client.id,
            code_verifier: code_verifier
          }
        )

        unless response.success?
          Rails.logger.error(
            "Lichess token exchange failed: status=#{response.status} body=#{response.body} " \
            "redirect_uri=#{callback_url} client_id=#{client.id}"
          )
          error_body = JSON.parse(response.body)
          raise ::OAuth2::Error, error_body
        end

        parsed = JSON.parse(response.body)
        ::OAuth2::AccessToken.from_hash(client, parsed)
      rescue JSON::ParserError => e
        raise ::OAuth2::Error, {
          "error" => "token_exchange_failed",
          "error_description" => e.message
        }
      end

      private

      def pkce_cache_key(state)
        "#{PKCE_CACHE_PREFIX}:#{state}"
      end
    end
  end
end
