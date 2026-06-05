# frozen_string_literal: true

# == Schema Information
#
# Table name: weakness_cycles
#
#  id                     :string           not null, primary key
#  baseline_occurrences   :integer          default(0), not null
#  baseline_severity      :decimal(5, 2)
#  current_occurrences    :integer          default(0), not null
#  current_severity       :decimal(5, 2)
#  cycle_number           :integer          default(1), not null
#  detection_window_days  :integer
#  detection_window_games :integer
#  ended_at               :datetime
#  improvement_percentage :decimal(5, 2)
#  metadata               :jsonb            not null
#  started_at             :datetime
#  status                 :integer          default("detected"), not null
#  theme                  :integer          not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  user_id                :string           not null
#
# Indexes
#
#  index_weakness_cycles_on_user_id             (user_id)
#  index_weakness_cycles_on_user_id_and_status  (user_id,status)
#  index_weakness_cycles_on_user_id_and_theme   (user_id,theme)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :weakness_cycle do
    user
    theme { :missed_tactics }
    status { :detected }
    cycle_number { 1 }
    baseline_occurrences { 5 }
    current_occurrences { 5 }
    baseline_severity { 0.8 }
    current_severity { 0.8 }
    detection_window_games { 10 }
    detection_window_days { 30 }
    started_at { 7.days.ago }
    metadata { {} }

    trait :active do
      status { :active }
    end
  end
end
