# frozen_string_literal: true

# == Schema Information
#
# Table name: training_plans
#
#  id                    :string           not null, primary key
#  baseline_occurrences  :integer          default(0), not null
#  completed_at          :datetime
#  current_occurrences   :integer          default(0), not null
#  ends_at               :datetime
#  improvement_threshold :decimal(5, 2)
#  managed_threshold     :decimal(5, 2)
#  metadata              :jsonb            not null
#  progress_percentage   :decimal(5, 2)
#  starts_at             :datetime
#  status                :integer          default("recommended"), not null
#  theme                 :integer          not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  user_id               :string           not null
#  weakness_cycle_id     :string           not null
#
# Indexes
#
#  index_training_plans_on_user_id             (user_id)
#  index_training_plans_on_user_id_and_status  (user_id,status)
#  index_training_plans_on_weakness_cycle_id   (weakness_cycle_id)
#  index_training_plans_one_active_per_user    (user_id) UNIQUE WHERE (status = 1)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#  fk_rails_...  (weakness_cycle_id => weakness_cycles.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :training_plan do
    user
    weakness_cycle { association :weakness_cycle, user: user, theme: theme }
    theme { :missed_tactics }
    status { :recommended }
    starts_at { Time.current }
    improvement_threshold { 0.5 }
    managed_threshold { 0.2 }
    baseline_occurrences { 5 }
    current_occurrences { 5 }
    progress_percentage { 0.0 }
    metadata { {} }

    trait :active do
      status { :active }
    end
  end
end
