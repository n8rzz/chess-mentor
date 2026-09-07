# frozen_string_literal: true

# == Schema Information
#
# Table name: engine_position_evals
#
#  id               :string           not null, primary key
#  analysis_version :string           not null
#  depth            :integer          not null
#  engine_name      :string           not null
#  engine_version   :string           not null
#  multipv          :integer          not null
#  position_key     :string           not null
#  result           :jsonb            not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_engine_position_evals_on_cache_key  (position_key,engine_name,engine_version,depth,multipv,analysis_version) UNIQUE
#
require "rails_helper"

RSpec.describe EnginePositionEval, type: :model do
  subject(:cache_row) { build(:engine_position_eval) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:position_key) }
    it { is_expected.to validate_presence_of(:engine_name) }
    it { is_expected.to validate_presence_of(:engine_version) }
    it { is_expected.to validate_presence_of(:analysis_version) }
    it { is_expected.to validate_presence_of(:depth) }
    it { is_expected.to validate_presence_of(:multipv) }

    it "requires a unique cache key" do
      existing = create(:engine_position_eval)
      duplicate = build(
        :engine_position_eval,
        position_key: existing.position_key,
        engine_name: existing.engine_name,
        engine_version: existing.engine_version,
        depth: existing.depth,
        multipv: existing.multipv,
        analysis_version: existing.analysis_version
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:position_key]).to include("has already been taken")
    end
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      cache_row.save!

      expect(cache_row.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end
end
