# frozen_string_literal: true

# Historical progress snapshots for dashboard chart dev (depends on 07_demo_training).
return unless Rails.env.development?

user = User.find_by(email: "starship@example.com")
return unless user

plan = TrainingPlan.find_by("metadata->>'seed_key' = ?", "demo_training_plan")
cycle = plan&.weakness_cycle
return unless plan && cycle

seed_key = "demo_progress_snapshots"
return if ProgressSnapshot.exists?([ "metadata->>'seed_key' = ?", seed_key ])

8.times do |week_index|
  snapshot_at = (7 - week_index).weeks.ago.beginning_of_day
  rating = 1480 + (week_index * 15)
  occurrences = [ cycle.baseline_occurrences - week_index, 1 ].max
  frequency = (occurrences.to_f / cycle.detection_window_games).round(4)
  blunders_per_game = (1.2 - (week_index * 0.08)).round(2)
  average_cpl = (48.0 - (week_index * 2.5)).round(2)
  training_completion = [ week_index * 12, 96 ].min

  ProgressSnapshot.create!(
    user: user,
    time_class: :blitz,
    rating: rating,
    snapshot_at: snapshot_at,
    metadata: { "kind" => "rating", "seed_key" => seed_key }
  )

  ProgressSnapshot.create!(
    user: user,
    time_class: :unknown,
    blunders_per_game: blunders_per_game,
    average_centipawn_loss: average_cpl,
    games_analyzed_count: 10 + week_index,
    snapshot_at: snapshot_at,
    metadata: { "kind" => "performance", "seed_key" => seed_key }
  )

  ProgressSnapshot.create!(
    user: user,
    weakness_cycle: cycle,
    weakness_frequency: frequency,
    weakness_severity: cycle.current_severity,
    snapshot_at: snapshot_at,
    metadata: {
      "kind" => "weakness",
      "seed_key" => seed_key,
      "current_occurrences" => occurrences
    }
  )

  ProgressSnapshot.create!(
    user: user,
    training_plan: plan,
    weakness_cycle: cycle,
    snapshot_at: snapshot_at,
    metadata: {
      "kind" => "training",
      "seed_key" => seed_key,
      "plan_progress_percentage" => [ week_index * 10, 100 ].min,
      "training_completion_percentage" => training_completion
    }
  )
end
