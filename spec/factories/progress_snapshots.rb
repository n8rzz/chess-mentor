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
#  rating                 :integer
#  snapshot_at            :datetime         not null
#  time_class             :integer          default("unknown"), not null
#  weakness_frequency     :decimal(5, 2)
#  weakness_severity      :decimal(5, 2)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  training_plan_id       :string
#  user_id                :string           not null
#  weakness_cycle_id      :string
#
# Indexes
#
#  index_progress_snapshots_on_training_plan_id         (training_plan_id)
#  index_progress_snapshots_on_user_id                  (user_id)
#  index_progress_snapshots_on_user_id_and_snapshot_at  (user_id,snapshot_at)
#  index_progress_snapshots_on_weakness_cycle_id        (weakness_cycle_id)
#
# Foreign Keys
#
#  fk_rails_...  (training_plan_id => training_plans.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#  fk_rails_...  (weakness_cycle_id => weakness_cycles.id) ON DELETE => nullify
#
FactoryBot.define do
  factory :progress_snapshot do
    user
    training_plan { association :training_plan, user: user }
    weakness_cycle { training_plan.weakness_cycle }
    time_class { :blitz }
    rating { 1520 }
    weakness_frequency { 0.4 }
    weakness_severity { 0.6 }
    blunders_per_game { 0.8 }
    average_centipawn_loss { 42.5 }
    games_analyzed_count { 10 }
    snapshot_at { Time.current }
    metadata { {} }
  end
end
