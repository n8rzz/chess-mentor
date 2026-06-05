# frozen_string_literal: true

# == Schema Information
#
# Table name: puzzles
#
#  id         :string           not null, primary key
#  difficulty :integer          default("easy"), not null
#  fen        :string           not null
#  metadata   :jsonb            not null
#  motif      :integer          not null
#  rating     :integer
#  solution   :text             not null
#  source     :integer          default("curated"), not null
#  theme      :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :puzzle do
    source { :curated }
    fen { "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4" }
    solution { "f3g5 f6g5 d1g4" }
    theme { :missed_tactics }
    motif { :fork }
    rating { 1200 }
    difficulty { :medium }
    metadata { {} }
  end
end
