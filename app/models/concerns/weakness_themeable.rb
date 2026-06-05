# frozen_string_literal: true

module WeaknessThemeable
  extend ActiveSupport::Concern

  THEMES = {
    hanging_pieces: 0,
    missed_tactics: 1,
    ignored_threats: 2,
    opening_development: 3,
    king_safety: 4,
    bad_trades: 5,
    pawn_structure: 6,
    endgame_technique: 7,
    time_pressure: 8
  }.freeze

  included do
    enum :theme, THEMES, validate: true
  end
end
