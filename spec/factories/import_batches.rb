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
FactoryBot.define do
  factory :import_batch do
    user
    provider_account { association :provider_account, user: user }
    provider { :lichess }
    status { :pending }
    requested_since { 30.days.ago }
    requested_until { Time.current }
    max_games { 30 }
    time_controls { %w[blitz rapid] }
    metadata { {} }

    trait :running do
      status { :running }
      started_at { Time.current }
    end

    trait :succeeded do
      status { :succeeded }
      started_at { 5.minutes.ago }
      finished_at { Time.current }
      games_found_count { 10 }
      games_imported_count { 10 }
    end

    trait :failed do
      status { :failed }
      started_at { 5.minutes.ago }
      finished_at { Time.current }
      error_message { "import failed" }
    end
  end
end
