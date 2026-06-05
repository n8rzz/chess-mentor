# frozen_string_literal: true

# == Schema Information
#
# Table name: import_batches
#
#  id                   :string           not null, primary key
#  error_details        :jsonb
#  error_message        :text
#  finished_at          :datetime
#  games_failed_count   :integer          default(0), not null
#  games_found_count    :integer          default(0), not null
#  games_imported_count :integer          default(0), not null
#  games_skipped_count  :integer          default(0), not null
#  max_games            :integer          not null
#  metadata             :jsonb            not null
#  provider             :integer          not null
#  requested_since      :datetime         not null
#  requested_until      :datetime         not null
#  started_at           :datetime
#  status               :integer          default("pending"), not null
#  time_controls        :jsonb            not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  provider_account_id  :string           not null
#  user_id              :string           not null
#
# Indexes
#
#  index_import_batches_on_provider_account_id     (provider_account_id)
#  index_import_batches_on_user_id                 (user_id)
#  index_import_batches_on_user_id_and_created_at  (user_id,created_at)
#  index_import_batches_on_user_id_and_status      (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (provider_account_id => provider_accounts.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class ImportBatch < ApplicationRecord
  include ProviderIdentifiable

  belongs_to :user
  belongs_to :provider_account
  has_many :import_records, dependent: :destroy
  has_many :games, dependent: :destroy

  enum :status, {
    pending: 0,
    running: 1,
    succeeded: 2,
    partially_succeeded: 3,
    failed: 4,
    cancelled: 5
  }, default: :pending, validate: true

  validates :requested_since, :requested_until, :max_games, presence: true
  validates :max_games, numericality: { greater_than: 0, less_than_or_equal_to: 30 }
  validate :time_controls_must_be_array

  scope :in_progress, -> { where(status: %i[pending running]) }
  scope :terminal, -> { where(status: %i[succeeded partially_succeeded failed cancelled]) }

  private

  def time_controls_must_be_array
    return if time_controls.is_a?(Array)

    errors.add(:time_controls, "must be an array")
  end
end
