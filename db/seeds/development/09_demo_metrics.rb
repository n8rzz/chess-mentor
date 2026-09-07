# frozen_string_literal: true

# Demo review periods + performance metrics via the real Python calculators
# (depends on 05_demo_analysis succeeded runs).
return unless Rails.env.development?

user = User.find_by(email: "starship@example.com")
return unless user

seed_key = "demo_review_period_metrics"
return if ReviewPeriod.exists?([ "metadata->>'seed_key' = ?", seed_key ])

analyzed_runs = AnalysisRun
  .succeeded
  .joins(:game)
  .where(games: { user_id: user.id })
  .includes(:game, :move_evaluations)
  .order("games.played_at ASC")
  .select { |run| run.move_evaluations.any? }

return if analyzed_runs.empty?

analyzed_runs.each do |run|
  next if GameMetric.exists?(analysis_run_id: run.id)

  Metrics::PythonRunner.persist_game_metrics!(analysis_run_id: run.id)
end

games = analyzed_runs.map(&:game).uniq
recent_games = games.last([ games.size, 5 ].min)
earlier_games = games.first([ games.size, 3 ].min)

recent = ReviewPeriods::CreateFromGames.call(
  user: user,
  games: recent_games,
  label: "Demo recent games",
  status: :active,
  metadata: { "seed_key" => seed_key, "window" => "recent" }
)

earlier = nil
if earlier_games.map(&:id).sort != recent_games.map(&:id).sort
  earlier = ReviewPeriods::CreateFromGames.call(
    user: user,
    games: earlier_games,
    label: "Demo earlier games",
    status: :completed,
    metadata: { "seed_key" => "#{seed_key}_earlier", "window" => "earlier" }
  )
end

Metrics::PythonRunner.refresh_review_period_metrics!(user_id: user.id)

# CreateFromGames enqueues refresh jobs; cancel leftovers now that we refreshed inline.
user.system_jobs.refresh_review_period_metrics.pending.find_each(&:cancel!)

recent_metric = recent.review_period_metrics.find_by(metric_formula_version: AnalysisVersions::METRIC_FORMULA_VERSION)
earlier_metric = earlier&.review_period_metrics&.find_by(metric_formula_version: AnalysisVersions::METRIC_FORMULA_VERSION)

puts(
  "Seeded demo metrics for #{user.email}: " \
  "#{GameMetric.where(user: user).count} game_metrics, " \
  "recent period ACPL=#{recent_metric&.average_centipawn_loss}, " \
  "earlier period ACPL=#{earlier_metric&.average_centipawn_loss}"
)
