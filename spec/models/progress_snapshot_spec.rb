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
require "rails_helper"

RSpec.describe ProgressSnapshot, type: :model do
  subject(:progress_snapshot) { build(:progress_snapshot) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:training_plan).optional }
    it { is_expected.to belong_to(:weakness_cycle).optional }
  end

  describe "enums" do
    it do
      expect(progress_snapshot).to define_enum_for(:time_class)
        .with_values(bullet: 0, blitz: 1, rapid: 2, classical: 3, unknown: 4)
        .backed_by_column_of_type(:integer)
        .with_default(:unknown)
        .with_prefix(:time_class)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:snapshot_at) }
    it { is_expected.to validate_numericality_of(:games_analyzed_count).is_greater_than_or_equal_to(0) }
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      progress_snapshot.save!

      expect(progress_snapshot.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end
end
