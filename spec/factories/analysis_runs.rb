# frozen_string_literal: true

# == Schema Information
#
# Table name: analysis_runs
#
#  id               :string           not null, primary key
#  analysis_version :string           not null
#  depth            :integer          not null
#  engine_name      :string           not null
#  engine_version   :string           not null
#  error_details    :jsonb
#  error_message    :text
#  finished_at      :datetime
#  metadata         :jsonb            not null
#  started_at       :datetime
#  status           :integer          default("pending"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  game_id          :string           not null
#  user_id          :string           not null
#
# Indexes
#
#  index_analysis_runs_on_game_id             (game_id)
#  index_analysis_runs_on_user_id             (user_id)
#  index_analysis_runs_on_user_id_and_status  (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :analysis_run do
    game
    user { game.user }
    status { :pending }
    engine_name { "Stockfish" }
    engine_version { "16.1" }
    analysis_version { "1.0.0" }
    depth { 15 }
    metadata { {} }

    trait :running do
      status { :running }
      started_at { Time.current }
    end

    trait :succeeded do
      status { :succeeded }
      started_at { 2.minutes.ago }
      finished_at { Time.current }
    end

    trait :failed do
      status { :failed }
      started_at { 2.minutes.ago }
      finished_at { Time.current }
      error_message { "analysis failed" }
    end
  end
end
