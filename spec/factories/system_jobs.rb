# frozen_string_literal: true

# == Schema Information
#
# Table name: system_jobs
#
#  id             :string           not null, primary key
#  attempts_count :integer          default(0), not null
#  claimed_by     :string
#  error_details  :jsonb
#  error_message  :text
#  finished_at    :datetime
#  job_type       :integer          not null
#  payload        :jsonb            not null
#  result         :jsonb
#  started_at     :datetime
#  status         :integer          default("pending"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :string           not null
#
# Indexes
#
#  index_system_jobs_on_status_and_created_at   (status,created_at)
#  index_system_jobs_on_user_id                 (user_id)
#  index_system_jobs_on_user_id_and_created_at  (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :system_job do
    user
    job_type { :import_games }
    status { :pending }
    payload { {} }
    attempts_count { 0 }

    trait :claimed do
      status { :claimed }
      claimed_by { "worker-1" }
      started_at { Time.current }
      attempts_count { 1 }
    end

    trait :processing do
      status { :processing }
      claimed_by { "worker-1" }
      started_at { Time.current }
      attempts_count { 1 }
    end

    trait :succeeded do
      status { :succeeded }
      claimed_by { "worker-1" }
      started_at { 1.minute.ago }
      finished_at { Time.current }
      result { { "stub" => true } }
      attempts_count { 1 }
    end

    trait :failed do
      status { :failed }
      claimed_by { "worker-1" }
      started_at { 1.minute.ago }
      finished_at { Time.current }
      error_message { "handler error" }
      attempts_count { 1 }
    end

    trait :cancelled do
      status { :cancelled }
      finished_at { Time.current }
    end

    trait :analyze_game do
      job_type { :analyze_game }
      payload { { "analysis_run_id" => "01TEST", "game_id" => "01GAME" } }
    end
  end
end
