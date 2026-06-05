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
require "rails_helper"

RSpec.describe TrainingAssignment, type: :model do
  subject(:training_assignment) { build(:training_assignment) }

  describe "associations" do
    it { is_expected.to belong_to(:training_plan) }
    it { is_expected.to belong_to(:source_game).class_name("Game").optional }
    it { is_expected.to belong_to(:source_move).class_name("Move").optional }
    it { is_expected.to belong_to(:puzzle).optional }
  end

  describe "enums" do
    it do
      expect(training_assignment).to define_enum_for(:assignment_type)
        .with_values(
          personal_position_review: 0,
          theme_puzzle: 1,
          play_game: 2,
          habit_exercise: 3
        )
        .backed_by_column_of_type(:integer)
    end

    it do
      expect(training_assignment).to define_enum_for(:status)
        .with_values(pending: 0, completed: 1, skipped: 2)
        .backed_by_column_of_type(:integer)
        .with_default(:pending)
    end
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      training_assignment.save!

      expect(training_assignment.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end
end
