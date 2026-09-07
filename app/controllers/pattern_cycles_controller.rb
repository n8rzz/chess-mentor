# frozen_string_literal: true

class PatternCyclesController < ApplicationController
  layout "dashboard"

  before_action :authenticate_user!
  before_action :set_pattern_cycle, only: :show

  VISIBLE_STATUSES = %i[detected active improving managed].freeze

  def index
    @pattern_cycles = current_user.pattern_cycles
      .where(status: VISIBLE_STATUSES)
      .order(current_severity: :desc, current_occurrences: :desc)
  end

  def show
    @pattern_occurrences = @pattern_cycle.pattern_occurrences
      .includes(:game, :move)
      .order(created_at: :desc)
  end

  private

  def set_pattern_cycle
    @pattern_cycle = current_user.pattern_cycles.find(params[:id])
  end
end
