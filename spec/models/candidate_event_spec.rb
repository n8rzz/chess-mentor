# frozen_string_literal: true

# == Schema Information
#
# Table name: candidate_events
#
#  id              :string           not null, primary key
#  confidence      :decimal(5, 2)    not null
#  event_type      :integer          not null
#  metadata        :jsonb            not null
#  severity        :decimal(5, 2)    not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  analysis_run_id :string           not null
#  game_id         :string           not null
#  move_id         :string           not null
#
# Indexes
#
#  index_candidate_events_on_analysis_run_id  (analysis_run_id)
#  index_candidate_events_on_game_id          (game_id)
#  index_candidate_events_on_move_id          (move_id)
#
# Foreign Keys
#
#  fk_rails_...  (analysis_run_id => analysis_runs.id) ON DELETE => cascade
#  fk_rails_...  (game_id => games.id) ON DELETE => cascade
#  fk_rails_...  (move_id => moves.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe CandidateEvent, type: :model do
  subject(:candidate_event) { build(:candidate_event) }

  describe "associations" do
    it { is_expected.to belong_to(:analysis_run) }
    it { is_expected.to belong_to(:game) }
    it { is_expected.to belong_to(:move) }
  end

  describe "enums" do
    it do
      expect(candidate_event).to define_enum_for(:event_type)
        .with_values(
          material: 0,
          tactical: 1,
          threat: 2,
          king_safety: 3,
          pawn_structure: 4,
          endgame_phase: 5,
          time_pressure: 6
        )
        .backed_by_column_of_type(:integer)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:severity) }
    it { is_expected.to validate_presence_of(:confidence) }
    it { is_expected.to validate_numericality_of(:severity).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(1) }
    it { is_expected.to validate_numericality_of(:confidence).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(1) }
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      candidate_event.save!

      expect(candidate_event.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end
end
