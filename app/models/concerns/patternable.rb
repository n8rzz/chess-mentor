# frozen_string_literal: true

module Patternable
  extend ActiveSupport::Concern

  PATTERNS = {
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

  PATTERN_LABELS = PATTERNS.keys.index_with { |key| key.to_s.humanize }.freeze

  included do
    enum :pattern, PATTERNS, validate: true
  end

  def pattern_label
    PATTERN_LABELS.fetch(pattern.to_sym)
  end
end
