# frozen_string_literal: true

module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    def lichess
      user = ProviderAccounts::ConnectLichess.call(
        auth: request.env["omniauth.auth"],
        current_user: current_user
      )

      if user_signed_in? && current_user == user
        redirect_to dashboard_path, notice: "Lichess account connected successfully."
      else
        sign_in_and_redirect user, event: :authentication
      end
    rescue ProviderAccounts::ConnectLichess::ConflictError
      redirect_to dashboard_path, alert: "That Lichess account is already linked to another user."
    rescue ProviderAccounts::ConnectLichess::ProfileFetchError => e
      redirect_to dashboard_path, alert: e.message
    end

    def failure
      message = omniauth_failure_message

      if user_signed_in?
        redirect_to dashboard_path, alert: message
      else
        redirect_to new_user_session_path, alert: message
      end
    end

    private

    def omniauth_failure_message
      exception = request.env["omniauth.error"]
      if exception&.message.present?
        return "Could not connect Lichess: #{exception.message}"
      end

      failure_message.presence || "Could not connect your Lichess account."
    end
  end
end
