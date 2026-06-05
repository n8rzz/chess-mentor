# frozen_string_literal: true

# == Schema Information
#
# Table name: weakness_cycles
#
#  id                     :string           not null, primary key
#  baseline_occurrences   :integer          default(0), not null
#  baseline_severity      :decimal(5, 2)
#  current_occurrences    :integer          default(0), not null
#  current_severity       :decimal(5, 2)
#  cycle_number           :integer          default(1), not null
#  detection_window_days  :integer
#  detection_window_games :integer
#  ended_at               :datetime
#  improvement_percentage :decimal(5, 2)
#  metadata               :jsonb            not null
#  started_at             :datetime
#  status                 :integer          default("detected"), not null
#  theme                  :integer          not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  user_id                :string           not null
#
# Indexes
#
#  index_weakness_cycles_on_user_id             (user_id)
#  index_weakness_cycles_on_user_id_and_status  (user_id,status)
#  index_weakness_cycles_on_user_id_and_theme   (user_id,theme)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe WeaknessCycle, type: :model do
  subject(:weakness_cycle) { build(:weakness_cycle) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:weakness_events).dependent(:destroy) }
    it { is_expected.to have_many(:training_plans).dependent(:destroy) }
  end

  describe "enums" do
    it do
      expect(weakness_cycle).to define_enum_for(:status)
        .with_values(detected: 0, active: 1, improving: 2, managed: 3, archived: 4)
        .backed_by_column_of_type(:integer)
        .with_default(:detected)
    end

    it do
      expect(weakness_cycle).to define_enum_for(:theme)
        .with_values(
          hanging_pieces: 0,
          missed_tactics: 1,
          ignored_threats: 2,
          opening_development: 3,
          king_safety: 4,
          bad_trades: 5,
          pawn_structure: 6,
          endgame_technique: 7,
          time_pressure: 8
        )
        .backed_by_column_of_type(:integer)
    end
  end

  describe "validations" do
    it { is_expected.to validate_numericality_of(:cycle_number).is_greater_than(0) }
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      weakness_cycle.save!

      expect(weakness_cycle.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end
end
