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
    @pending_analysis_count = @games.count { |game| game.analysis_runs.any?(&:pending?) }
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
