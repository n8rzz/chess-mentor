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
FactoryBot.define do
  factory :training_assignment do
    training_plan
    assignment_type { :theme_puzzle }
    status { :pending }
    due_on { Date.current }
    puzzle { association :puzzle, theme: training_plan.theme }
    prompt { "Solve this tactics puzzle." }
    metadata { {} }

    trait :completed do
      status { :completed }
      completed_at { Time.current }
    end

    trait :personal_review do
      assignment_type { :personal_position_review }
      puzzle { nil }
      source_game { association :game, user: training_plan.user }
      source_move { association :move, game: source_game }
      prompt { "Review this position from your game." }
    end
  end
end
