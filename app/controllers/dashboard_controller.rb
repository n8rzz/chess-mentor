# frozen_string_literal: true

class DashboardController < ApplicationController
  layout "dashboard"

  before_action :authenticate_user!

  def show
    @provider_accounts = current_user.provider_accounts
    @lichess_account = current_user.lichess_account
  end
end
