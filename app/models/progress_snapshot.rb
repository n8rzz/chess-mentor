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
class ProgressSnapshot < ApplicationRecord
  belongs_to :user
  belongs_to :training_plan, optional: true
  belongs_to :weakness_cycle, optional: true

  enum :time_class, {
    bullet: 0,
    blitz: 1,
    rapid: 2,
    classical: 3,
    unknown: 4
  }, default: :unknown, validate: true, prefix: :time_class

  validates :snapshot_at, presence: true
  validates :games_analyzed_count, numericality: { greater_than_or_equal_to: 0 }
end
