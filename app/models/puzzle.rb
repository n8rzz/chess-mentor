# frozen_string_literal: true

# == Schema Information
#
# Table name: puzzles
#
#  id         :string           not null, primary key
#  difficulty :integer          default("easy"), not null
#  fen        :string           not null
#  metadata   :jsonb            not null
#  motif      :integer          not null
#  rating     :integer
#  solution   :text             not null
#  source     :integer          default("curated"), not null
#  theme      :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Puzzle < ApplicationRecord
  include WeaknessThemeable
  include PuzzleMotifable

  has_many :training_assignments, dependent: :nullify

  enum :source, { curated: 0, user_generated: 1 }, validate: true
  enum :difficulty, { easy: 0, medium: 1, hard: 2 }, validate: true

  validates :fen, :solution, :motif, presence: true
end
