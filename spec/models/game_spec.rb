# frozen_string_literal: true

# == Schema Information
#
# Table name: games
#
#  id                  :string           not null, primary key
#  metadata            :jsonb            not null
#  opening_eco         :string
#  opening_name        :string
#  opponent_rating     :integer
#  opponent_username   :string
#  pgn                 :text             not null
#  played_at           :datetime         not null
#  provider            :integer          not null
#  result              :integer          not null
#  time_class          :integer          default("unknown"), not null
#  time_control        :string
#  user_color          :integer          not null
#  user_rating         :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  import_batch_id     :string           not null
#  provider_account_id :string           not null
#  provider_game_id    :string           not null
#  user_id             :string           not null
#
# Indexes
#
#  index_games_on_import_batch_id                            (import_batch_id)
#  index_games_on_provider_account_id                        (provider_account_id)
#  index_games_on_user_id                                    (user_id)
#  index_games_on_user_id_and_played_at                      (user_id,played_at)
#  index_games_on_user_id_and_provider_and_provider_game_id  (user_id,provider,provider_game_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (import_batch_id => import_batches.id) ON DELETE => cascade
#  fk_rails_...  (provider_account_id => provider_accounts.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe Game, type: :model do
  subject(:game) { build(:game) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:provider_account) }
    it { is_expected.to belong_to(:import_batch) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:provider).with_values(lichess: 0, chess_com: 1).backed_by_column_of_type(:integer) }
    it { is_expected.to define_enum_for(:user_color).with_values(white: 0, black: 1).backed_by_column_of_type(:integer) }
    it { is_expected.to define_enum_for(:result).with_values(win: 0, loss: 1, draw: 2, unknown: 3).backed_by_column_of_type(:integer) }
    it do
      expect(game).to define_enum_for(:time_class)
        .with_values(bullet: 0, blitz: 1, rapid: 2, classical: 3, unknown: 4)
        .backed_by_column_of_type(:integer)
        .with_default(:unknown)
        .with_prefix(:time_class)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:provider_game_id) }
    it { is_expected.to validate_presence_of(:pgn) }
    it { is_expected.to validate_presence_of(:played_at) }

    it "requires a unique provider_game_id per user and provider" do
      existing = create(:game, provider_game_id: "game-abc")
      duplicate = build(
        :game,
        user: existing.user,
        provider: existing.provider,
        provider_game_id: "game-abc"
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:provider_game_id]).to include("has already been taken")
    end
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      game.save!

      expect(game.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end
end
