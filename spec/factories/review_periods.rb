# frozen_string_literal: true

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
