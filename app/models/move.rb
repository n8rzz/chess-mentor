# frozen_string_literal: true

# == Schema Information
#
# Table name: moves
#
#  id             :string           not null, primary key
#  clock_after    :integer
#  clock_before   :integer
#  color          :integer          not null
#  fen_after      :string           not null
#  fen_before     :string           not null
#  move_number    :integer          not null
#  played_by_user :boolean          default(FALSE), not null
#  ply            :integer          not null
#  san            :string           not null
#  uci            :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  game_id        :string           not null
#
# Indexes
#
#  index_moves_on_game_id          (game_id)
#  index_moves_on_game_id_and_ply  (game_id,ply) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id) ON DELETE => cascade
#
class Move < ApplicationRecord
  belongs_to :game
  has_one :move_evaluation, dependent: :destroy
  has_many :candidate_events, dependent: :destroy
  has_many :weakness_events, dependent: :destroy

  enum :color, { white: 0, black: 1 }, validate: true

  validates :ply, :move_number, :san, :uci, :fen_before, :fen_after, presence: true
  validates :ply, uniqueness: { scope: :game_id }
end
