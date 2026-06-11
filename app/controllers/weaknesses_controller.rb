# frozen_string_literal: true

class WeaknessesController < ApplicationController
  layout "dashboard"

  before_action :authenticate_user!
  before_action :set_weakness_cycle, only: :show

  VISIBLE_STATUSES = %i[detected active improving managed].freeze

  def index
    @weakness_cycles = current_user.weakness_cycles
      .where(status: VISIBLE_STATUSES)
      .order(current_severity: :desc, current_occurrences: :desc)
  end

  def show
    @weakness_events = @weakness_cycle.weakness_events
      .includes(:game, :move)
      .order(created_at: :desc)
  end

  private

  def set_weakness_cycle
    @weakness_cycle = current_user.weakness_cycles.find(params[:id])
  end
end
