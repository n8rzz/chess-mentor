# frozen_string_literal: true

class DashboardController < ApplicationController
  layout "dashboard"

  before_action :authenticate_user!

  def show
    @provider_accounts = current_user.provider_accounts
    @lichess_account = current_user.lichess_account
    @latest_import_batch = current_user.import_batches.order(created_at: :desc).first
  end
end
