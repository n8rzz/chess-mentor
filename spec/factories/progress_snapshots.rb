# frozen_string_literal: true

# == Schema Information
#
# Table name: progress_snapshots
#
#  id                     :string           not null, primary key
#  average_centipawn_loss :decimal(8, 2)
#  blunders_per_game      :decimal(5, 2)
#  games_analyzed_count   :integer          default(0), not null
#  metadata               :jsonb            not null
#  pattern_frequency      :decimal(5, 2)
#  pattern_severity       :decimal(5, 2)
#  rating                 :integer
#  snapshot_at            :datetime         not null
#  time_class             :integer          default("unknown"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  pattern_cycle_id       :string
#  training_plan_id       :string
#  user_id                :string           not null
#
# Indexes
#
#  index_progress_snapshots_on_pattern_cycle_id         (pattern_cycle_id)
#  index_progress_snapshots_on_training_plan_id         (training_plan_id)
#  index_progress_snapshots_on_user_id                  (user_id)
#  index_progress_snapshots_on_user_id_and_snapshot_at  (user_id,snapshot_at)
#
# Foreign Keys
#
#  fk_rails_...  (pattern_cycle_id => pattern_cycles.id) ON DELETE => nullify
#  fk_rails_...  (training_plan_id => training_plans.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :progress_snapshot do
    user
    training_plan { association :training_plan, user: user }
    pattern_cycle { training_plan.pattern_cycle }
    time_class { :blitz }
    rating { 1520 }
    pattern_frequency { 0.4 }
    pattern_severity { 0.6 }
    blunders_per_game { 0.8 }
    average_centipawn_loss { 42.5 }
    games_analyzed_count { 10 }
    snapshot_at { Time.current }
    metadata { {} }
  end
end
