# frozen_string_literal: true

# == Schema Information
#
# Table name: review_periods
#
#  id         :string           not null, primary key
#  ends_at    :datetime         not null
#  label      :string           not null
#  max_games  :integer
#  metadata   :jsonb            not null
#  starts_at  :datetime         not null
#  status     :integer          default("draft"), not null
#  time_class :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :string           not null
#
# Indexes
#
#  index_review_periods_on_user_id                            (user_id)
#  index_review_periods_on_user_id_and_starts_at_and_ends_at  (user_id,starts_at,ends_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :review_period do
    user
    label { "Last 30 games" }
    starts_at { 30.days.ago }
    ends_at { Time.current }
    status { :active }
    metadata { {} }
  end

  factory :review_period_game do
    review_period
    game { association :game, user: review_period.user }
  end
end
