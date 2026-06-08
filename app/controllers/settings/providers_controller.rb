# frozen_string_literal: true

module Settings
  class ProvidersController < ApplicationController
    layout "dashboard"

    before_action :authenticate_user!

    def show
      @lichess_account = current_user.lichess_account
    end

    def disconnect
      provider_account = current_user.provider_accounts.find(params[:provider_account_id])

      ProviderAccounts::Disconnect.call(user: current_user, provider_account: provider_account)
      redirect_to settings_providers_path, notice: "Lichess account disconnected."
    rescue ProviderAccounts::Disconnect::ImportInProgressError => e
      redirect_to settings_providers_path, alert: e.message
    end
  end
end
