# frozen_string_literal: true

# == Schema Information
#
# Table name: training_assignments
#
#  id               :string           not null, primary key
#  assignment_type  :integer          not null
#  completed_at     :datetime
#  due_on           :date
#  metadata         :jsonb            not null
#  prompt           :text
#  status           :integer          default("pending"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  puzzle_id        :string
#  source_game_id   :string
#  source_move_id   :string
#  training_plan_id :string           not null
#
# Indexes
#
#  index_training_assignments_on_puzzle_id                    (puzzle_id)
#  index_training_assignments_on_source_game_id               (source_game_id)
#  index_training_assignments_on_source_move_id               (source_move_id)
#  index_training_assignments_on_training_plan_id             (training_plan_id)
#  index_training_assignments_on_training_plan_id_and_due_on  (training_plan_id,due_on)
#  index_training_assignments_on_training_plan_id_and_status  (training_plan_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (puzzle_id => puzzles.id) ON DELETE => nullify
#  fk_rails_...  (source_game_id => games.id) ON DELETE => nullify
#  fk_rails_...  (source_move_id => moves.id) ON DELETE => nullify
#  fk_rails_...  (training_plan_id => training_plans.id) ON DELETE => cascade
#
class TrainingAssignment < ApplicationRecord
  belongs_to :training_plan
  belongs_to :source_game, class_name: "Game", optional: true
  belongs_to :source_move, class_name: "Move", optional: true
  belongs_to :puzzle, optional: true

  enum :assignment_type, {
    personal_position_review: 0,
    theme_puzzle: 1,
    play_game: 2,
    habit_exercise: 3
  }, validate: true

  enum :status, {
    pending: 0,
    completed: 1,
    skipped: 2
  }, default: :pending, validate: true
end
