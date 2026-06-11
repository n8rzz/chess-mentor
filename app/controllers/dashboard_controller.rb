# frozen_string_literal: true

class DashboardController < ApplicationController
  layout "dashboard"

  before_action :authenticate_user!

  WEAKNESS_SUMMARY_STATUSES = %i[detected active improving managed].freeze

  def show
    @provider_accounts = current_user.provider_accounts
    @lichess_account = current_user.lichess_account
    @latest_import_batch = current_user.import_batches.order(created_at: :desc).first
    @top_weakness_cycles = current_user.weakness_cycles
      .where(status: WEAKNESS_SUMMARY_STATUSES)
      .order(current_severity: :desc, current_occurrences: :desc)
      .limit(3)
  end
end
