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
FactoryBot.define do
  factory :move do
    game
    ply { 1 }
    move_number { 1 }
    color { :white }
    san { "e4" }
    uci { "e2e4" }
    fen_before { "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" }
    fen_after { "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1" }
    played_by_user { true }
    clock_before { 300_000 }
    clock_after { 298_000 }
  end
end
