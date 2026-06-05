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
class AnalysisRun < ApplicationRecord
  TERMINAL_STATUSES = %w[succeeded partially_succeeded failed cancelled].freeze

  belongs_to :game
  belongs_to :user
  has_many :move_evaluations, dependent: :destroy
  has_many :candidate_events, dependent: :destroy

  enum :status, {
    pending: 0,
    running: 1,
    succeeded: 2,
    partially_succeeded: 3,
    failed: 4,
    cancelled: 5
  }, default: :pending, validate: true

  validates :engine_name, :engine_version, :analysis_version, :depth, presence: true

  validate :immutable_when_terminal, on: :update

  scope :in_progress, -> { where(status: %i[pending running]) }
  scope :terminal, -> { where(status: TERMINAL_STATUSES.map(&:to_sym)) }
  scope :succeeded, -> { where(status: :succeeded) }

  private

  def immutable_when_terminal
    return if new_record?
    return unless status_was.in?(TERMINAL_STATUSES)

    errors.add(:base, "terminal analysis runs cannot be modified")
  end
end
