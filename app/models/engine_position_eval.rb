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
class EnginePositionEval < ApplicationRecord
  validates :position_key, :engine_name, :engine_version, :analysis_version, presence: true
  validates :depth, :multipv, presence: true
  validates :position_key,
            uniqueness: {
              scope: %i[engine_name engine_version depth multipv analysis_version]
            }
end
