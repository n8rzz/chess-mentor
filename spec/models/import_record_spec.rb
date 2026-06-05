# frozen_string_literal: true

# == Schema Information
#
# Table name: import_records
#
#  id               :string           not null, primary key
#  error_message    :text
#  metadata         :jsonb            not null
#  provider         :integer          not null
#  status           :integer          default("pending"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  game_id          :string
#  import_batch_id  :string           not null
#  provider_game_id :string           not null
#
# Indexes
#
#  index_import_records_on_game_id                        (game_id)
#  index_import_records_on_import_batch_id                (import_batch_id)
#  index_import_records_on_provider_and_provider_game_id  (provider,provider_game_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id) ON DELETE => nullify
#  fk_rails_...  (import_batch_id => import_batches.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe ImportRecord, type: :model do
  subject(:import_record) { build(:import_record) }

  describe "associations" do
    it { is_expected.to belong_to(:import_batch) }
    it { is_expected.to belong_to(:game).optional }
  end

  describe "enums" do
    it do
      expect(import_record).to define_enum_for(:status)
        .with_values(pending: 0, imported: 1, skipped: 2, failed: 3)
        .backed_by_column_of_type(:integer)
        .with_default(:pending)
    end

    it { is_expected.to define_enum_for(:provider).with_values(lichess: 0, chess_com: 1).backed_by_column_of_type(:integer) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:provider_game_id) }

    it "requires a unique provider_game_id per provider" do
      create(:import_record, provider: :lichess, provider_game_id: "game-abc")
      duplicate = build(:import_record, provider: :lichess, provider_game_id: "game-abc")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:provider_game_id]).to include("has already been taken")
    end

    it "allows the same provider_game_id across different providers" do
      create(:import_record, provider: :lichess, provider_game_id: "game-abc")
      chess_com_record = build(:import_record, provider: :chess_com, provider_game_id: "game-abc")

      expect(chess_com_record).to be_valid
    end
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      import_record.save!

      expect(import_record.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end
end
