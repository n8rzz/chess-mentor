# frozen_string_literal: true

# == Schema Information
#
# Table name: import_records
#
#  id               :string           not null, primary key
#  error_message    :text
#  metadata         :jsonb            not null
#  provider         :integer          not null
#  status           :integer          default("pending"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  game_id          :string
#  import_batch_id  :string           not null
#  provider_game_id :string           not null
#
# Indexes
#
#  index_import_records_on_game_id                        (game_id)
#  index_import_records_on_import_batch_id                (import_batch_id)
#  index_import_records_on_provider_and_provider_game_id  (provider,provider_game_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id) ON DELETE => nullify
#  fk_rails_...  (import_batch_id => import_batches.id) ON DELETE => cascade
#
class ImportRecord < ApplicationRecord
  include ProviderIdentifiable

  belongs_to :import_batch
  belongs_to :game, optional: true

  enum :status, {
    pending: 0,
    imported: 1,
    skipped: 2,
    failed: 3
  }, default: :pending, validate: true

  validates :provider_game_id, presence: true
  validates :provider_game_id, uniqueness: { scope: :provider }
end
