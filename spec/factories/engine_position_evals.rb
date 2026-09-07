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
FactoryBot.define do
  factory :engine_position_eval do
    sequence(:position_key) { |n| "8/8/8/8/8/8/4P#{n % 8}3/4K2k w - -" }
    engine_name { AnalysisVersions::ENGINE_NAME }
    engine_version { AnalysisVersions::ENGINE_VERSION }
    depth { AnalysisVersions::DEPTH_SCAN }
    multipv { AnalysisVersions::MULTIPV }
    analysis_version { AnalysisVersions::ANALYSIS_VERSION }
    result do
      {
        "candidates" => [
          {
            "rank" => 1,
            "move_uci" => "e2e4",
            "move_san" => "e4",
            "eval_cp" => 25,
            "mate" => nil,
            "pv_san" => "e4"
          }
        ]
      }
    end
  end
end
