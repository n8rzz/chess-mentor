# frozen_string_literal: true

# == Schema Information
#
# Table name: review_period_games
#
#  id               :string           not null, primary key
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  game_id          :string           not null
#  review_period_id :string           not null
#
# Indexes
#
#  index_review_period_games_on_game_id                       (game_id)
#  index_review_period_games_on_review_period_id              (review_period_id)
#  index_review_period_games_on_review_period_id_and_game_id  (review_period_id,game_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id) ON DELETE => cascade
#  fk_rails_...  (review_period_id => review_periods.id) ON DELETE => cascade
#
class ReviewPeriodGame < ApplicationRecord
  belongs_to :review_period
  belongs_to :game

  validates :game_id, uniqueness: { scope: :review_period_id }
end
