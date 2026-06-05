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
class Game < ApplicationRecord
  include ProviderIdentifiable

  belongs_to :user
  belongs_to :provider_account
  belongs_to :import_batch

  enum :user_color, { white: 0, black: 1 }, validate: true
  enum :result, { win: 0, loss: 1, draw: 2, unknown: 3 }, validate: true
  enum :time_class, {
    bullet: 0,
    blitz: 1,
    rapid: 2,
    classical: 3,
    unknown: 4
  }, default: :unknown, validate: true, prefix: :time_class

  has_many :moves, dependent: :destroy
  has_many :analysis_runs, dependent: :destroy
  has_many :weakness_events, dependent: :destroy

  validates :provider_game_id, :pgn, :played_at, presence: true
  validates :provider_game_id, uniqueness: { scope: %i[user_id provider] }
end
