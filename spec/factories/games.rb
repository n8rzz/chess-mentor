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
FactoryBot.define do
  factory :game do
    user
    provider_account { association :provider_account, user: user }
    import_batch { association :import_batch, user: user, provider_account: provider_account }
    provider { :lichess }
    sequence(:provider_game_id) { |n| "lichess-game-#{n}" }
    pgn { "[Event \"Test\"]\n1. e4 e5 2. Nf3 Nc6 *" }
    played_at { 1.day.ago }
    user_color { :white }
    result { :win }
    time_control { "300+0" }
    time_class { :blitz }
    opening_name { "King's Pawn Game" }
    opening_eco { "C20" }
    user_rating { 1500 }
    opponent_rating { 1480 }
    opponent_username { "opponent1" }
    metadata { {} }
  end
end
