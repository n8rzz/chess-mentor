# frozen_string_literal: true

# == Schema Information
#
# Table name: move_evaluations
#
#  id                  :string           not null, primary key
#  best_move_san       :string
#  best_move_uci       :string
#  centipawn_loss      :integer          not null
#  classification      :integer          not null
#  depth               :integer          not null
#  eval_after_cp       :integer
#  eval_before_cp      :integer
#  mate_after          :integer
#  mate_before         :integer
#  metadata            :jsonb            not null
#  principal_variation :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  analysis_run_id     :string           not null
#  game_id             :string           not null
#  move_id             :string           not null
#
# Indexes
#
#  index_move_evaluations_on_analysis_run_id              (analysis_run_id)
#  index_move_evaluations_on_analysis_run_id_and_move_id  (analysis_run_id,move_id) UNIQUE
#  index_move_evaluations_on_game_id                      (game_id)
#  index_move_evaluations_on_move_id                      (move_id)
#
# Foreign Keys
#
#  fk_rails_...  (analysis_run_id => analysis_runs.id) ON DELETE => cascade
#  fk_rails_...  (game_id => games.id) ON DELETE => cascade
#  fk_rails_...  (move_id => moves.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe MoveEvaluation, type: :model do
  subject(:move_evaluation) { build(:move_evaluation) }

  describe "associations" do
    it { is_expected.to belong_to(:analysis_run) }
    it { is_expected.to belong_to(:game) }
    it { is_expected.to belong_to(:move) }
  end

  describe "enums" do
    it do
      expect(move_evaluation).to define_enum_for(:classification)
        .with_values(good: 0, inaccuracy: 1, mistake: 2, blunder: 3)
        .backed_by_column_of_type(:integer)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:centipawn_loss) }
    it { is_expected.to validate_presence_of(:depth) }

    it "requires a unique move per analysis run" do
      existing = create(:move_evaluation)
      duplicate = build(:move_evaluation, analysis_run: existing.analysis_run, move: existing.move)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:move_id]).to include("has already been taken")
    end
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      move_evaluation.save!

      expect(move_evaluation.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end
end
