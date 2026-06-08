# frozen_string_literal: true

class ImportBatchesController < ApplicationController
  layout "dashboard"

  before_action :authenticate_user!
  before_action :set_import_batch, only: :show
  before_action :require_lichess_account, only: %i[new create]

  def index
    @import_batches = current_user.import_batches.order(created_at: :desc).limit(20)
  end

  def new
    @lichess_account = current_user.lichess_account
  end

  def create
    batch = ImportBatches::Create.call(
      user: current_user,
      provider_account: current_user.lichess_account,
      days: import_params[:days],
      time_controls: import_params[:time_controls],
      max_games: import_params[:max_games].presence || ImportBatches::Create::MAX_GAMES_LIMIT
    )

    redirect_to import_batch_path(batch), notice: "Import started."
  rescue ImportBatches::Create::ImportInProgressError, ImportBatches::Create::InvalidFiltersError => e
    redirect_to new_import_batch_path, alert: e.message
  end

  def show
    AnalysisRuns::BulkEnqueueForImport.call(import_batch: @import_batch)
    @import_batch.reload
    @import_records = @import_batch.import_records.order(created_at: :desc).limit(50)
  end

  private

  def set_import_batch
    @import_batch = current_user.import_batches.find(params[:id])
  end

  def require_lichess_account
    return if current_user.lichess_account.present?

    redirect_to settings_providers_path, alert: "Connect your Lichess account before importing games."
  end

  def import_params
    params.require(:import).permit(:days, :max_games, time_controls: [])
  end
end
