# frozen_string_literal: true

class GamesController < ApplicationController
  layout "dashboard"

  before_action :authenticate_user!
  before_action :set_game, only: :show

  def index
    @games = current_user.games
      .includes(:analysis_runs)
      .order(played_at: :desc)
      .limit(50)
    @latest_runs_by_game_id = @games.to_h do |game|
      [game.id, game.analysis_runs.max_by(&:created_at)]
    end

    latest_runs = @latest_runs_by_game_id.values.compact
    @queued_analysis_count = latest_runs.count(&:pending?)
    @running_analysis_count = latest_runs.count(&:running?)
    @recently_succeeded_runs = latest_runs.select(&:recently_finished?)
    @analysis_refreshing = latest_runs.any?(&:in_progress?)
  end

  def show
    @analysis_run = @game.analysis_runs.order(created_at: :desc).first
    @succeeded_analysis_run = @game.analysis_runs.succeeded.order(created_at: :desc).first
    @moves = @game.moves.order(:ply)
    @evaluations_by_move_id = if @succeeded_analysis_run
      @succeeded_analysis_run.move_evaluations.index_by(&:move_id)
    else
      {}
    end
  end

  private

  def set_game
    @game = current_user.games.find(params[:id])
  end
end
