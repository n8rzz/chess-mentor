# frozen_string_literal: true

module GamePhaseable
  extend ActiveSupport::Concern

  PHASES = {
    opening: 0,
    middlegame: 1,
    endgame: 2
  }.freeze

  included do
    enum :phase, PHASES, validate: true
  end
end
