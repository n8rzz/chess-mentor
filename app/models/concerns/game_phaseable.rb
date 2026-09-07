# frozen_string_literal: true

module GamePhaseable
  extend ActiveSupport::Concern

  PHASES = {
    opening: 0,
    middlegame: 1,
    endgame: 2
  }.freeze

  included do
    # Moves may be null until analysis classifies them; pattern_occurrences
    # still enforce presence via their own validations.
    enum :phase, PHASES, validate: { allow_nil: true }
  end
end
