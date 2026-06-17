# frozen_string_literal: true

# Demo training plan and assignments for local UI dev (depends on 06_demo_weaknesses).
return unless Rails.env.development?

user = User.find_by(email: "starship@example.com")
return unless user

cycle = WeaknessCycle.find_by(user: user, theme: :missed_tactics, status: :active)
return unless cycle

seed_key = "demo_training_plan"
plan = TrainingPlan.find_by("metadata->>'seed_key' = ?", seed_key)

unless plan
  plan = TrainingPlan.create!(
    user: user,
    weakness_cycle: cycle,
    theme: cycle.theme,
    status: :active,
    starts_at: Time.current.beginning_of_day,
    ends_at: 14.days.from_now.end_of_day,
    baseline_occurrences: cycle.baseline_occurrences,
    current_occurrences: cycle.current_occurrences,
    improvement_threshold: TrainingPlan::DEFAULT_IMPROVEMENT_THRESHOLD,
    managed_threshold: TrainingPlan::DEFAULT_MANAGED_THRESHOLD,
    progress_percentage: 0.0,
    metadata: { "seed_key" => seed_key }
  )
end

def seed_demo_training_assignments!(plan, cycle)
  events = cycle.weakness_events.includes(:game, :move).order(created_at: :desc).to_a
  puzzles = Puzzle.curated.where(theme: plan.theme).order(:rating, :id).limit(5).to_a
  theme_label = plan.theme_label

  14.times do |day_index|
    due_on = plan.starts_at.to_date + day_index
    event = events[day_index % events.size] if events.any?

    TrainingAssignment.create!(
      training_plan: plan,
      assignment_type: :personal_position_review,
      due_on: due_on,
      status: :pending,
      source_game: event&.game,
      source_move: event&.move,
      prompt: "Review your mistake from this game position and find the best move.",
      metadata: { "seed_key" => "demo_review_#{day_index}" }
    )

    5.times do |slot|
      puzzle = puzzles[slot % puzzles.size] if puzzles.any?
      TrainingAssignment.create!(
        training_plan: plan,
        assignment_type: :theme_puzzle,
        due_on: due_on,
        status: :pending,
        puzzle: puzzle,
        metadata: { "seed_key" => "demo_puzzle_#{day_index}_#{slot}" }
      )
    end

    TrainingAssignment.create!(
      training_plan: plan,
      assignment_type: :play_game,
      due_on: due_on,
      status: :pending,
      prompt: "Play 1 rapid game focusing on #{theme_label}.",
      metadata: { "seed_key" => "demo_play_#{day_index}" }
    )

    TrainingAssignment.create!(
      training_plan: plan,
      assignment_type: :habit_exercise,
      due_on: due_on,
      status: :pending,
      prompt: "Before every move ask: Do I have a forcing move?",
      metadata: { "seed_key" => "demo_habit_#{day_index}" }
    )
  end
end

stale_plan = plan.archived? || plan.completed? || plan.ends_at&.past? || plan.assignments_for_today.none?

if stale_plan
  plan.training_assignments.destroy_all
  plan.update!(
    weakness_cycle: cycle,
    theme: cycle.theme,
    status: :active,
    completed_at: nil,
    starts_at: Time.current.beginning_of_day,
    ends_at: 14.days.from_now.end_of_day,
    baseline_occurrences: cycle.baseline_occurrences,
    current_occurrences: cycle.current_occurrences,
    improvement_threshold: TrainingPlan::DEFAULT_IMPROVEMENT_THRESHOLD,
    managed_threshold: TrainingPlan::DEFAULT_MANAGED_THRESHOLD,
    progress_percentage: 0.0
  )
  seed_demo_training_assignments!(plan, cycle)
elsif plan.training_assignments.none?
  seed_demo_training_assignments!(plan, cycle)
end

puts "Seeded demo training plan for #{user.email}: #{plan.theme_label} (#{plan.training_assignments.count} assignments, #{plan.assignments_for_today.count} due today)"
