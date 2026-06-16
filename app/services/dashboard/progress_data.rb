# frozen_string_literal: true

module Dashboard
  class ProgressData
    SNAPSHOT_KINDS = {
      rating: "rating",
      performance: "performance",
      weakness: "weakness",
      training: "training"
    }.freeze

    MAX_POINTS = 30
    LOOKBACK = 90.days

    Result = Data.define(
      :ratings_by_time_class,
      :weakness_trend,
      :blunders_per_game,
      :average_centipawn_loss,
      :has_chart_data
    )

    SeriesPoint = Data.define(:at, :value)
    WeaknessPoint = Data.define(:at, :occurrences, :frequency, :severity)

    def self.call(user:, active_plan: nil)
      new(user:, active_plan:).call
    end

    def initialize(user:, active_plan: nil)
      @user = user
      @active_plan = active_plan
    end

    def call
      snapshots = scoped_snapshots
      ratings = ratings_series(snapshots)
      weakness = weakness_series(snapshots)
      performance = performance_series(snapshots)

      Result.new(
        ratings_by_time_class: ratings,
        weakness_trend: weakness,
        blunders_per_game: performance[:blunders_per_game],
        average_centipawn_loss: performance[:average_centipawn_loss],
        has_chart_data: chart_data?(ratings, weakness, performance)
      )
    end

    private

    def scoped_snapshots
      @user.progress_snapshots
        .where(snapshot_at: LOOKBACK.ago..)
        .order(:snapshot_at)
        .to_a
    end

    def snapshots_for_kind(snapshots, kind)
      snapshots.select { |snapshot| snapshot.metadata["kind"] == kind }
    end

    def ratings_series(snapshots)
      rating_snapshots = snapshots_for_kind(snapshots, SNAPSHOT_KINDS[:rating])
      Dashboard::Summary::RATING_TIME_CLASSES.index_with do |time_class|
        points = rating_snapshots
          .select { |snapshot| snapshot.time_class == time_class.to_s }
          .map { |snapshot| SeriesPoint.new(at: snapshot.snapshot_at, value: snapshot.rating) }
        limit_series(points)
      end
    end

    def weakness_series(snapshots)
      weakness_snapshots = snapshots_for_kind(snapshots, SNAPSHOT_KINDS[:weakness])
      cycle_id = @active_plan&.weakness_cycle_id
      filtered = if cycle_id.present?
        weakness_snapshots.select { |snapshot| snapshot.weakness_cycle_id == cycle_id }
      else
        weakness_snapshots
      end

      points = filtered.map do |snapshot|
        WeaknessPoint.new(
          at: snapshot.snapshot_at,
          occurrences: snapshot.metadata["current_occurrences"],
          frequency: snapshot.weakness_frequency&.to_f,
          severity: snapshot.weakness_severity&.to_f
        )
      end
      limit_series(points)
    end

    def performance_series(snapshots)
      performance_snapshots = snapshots_for_kind(snapshots, SNAPSHOT_KINDS[:performance])
      blunders = performance_snapshots.filter_map do |snapshot|
        next if snapshot.blunders_per_game.blank?

        SeriesPoint.new(at: snapshot.snapshot_at, value: snapshot.blunders_per_game.to_f)
      end
      cpl = performance_snapshots.filter_map do |snapshot|
        next if snapshot.average_centipawn_loss.blank?

        SeriesPoint.new(at: snapshot.snapshot_at, value: snapshot.average_centipawn_loss.to_f)
      end

      {
        blunders_per_game: limit_series(blunders),
        average_centipawn_loss: limit_series(cpl)
      }
    end

    def limit_series(points)
      points.last(MAX_POINTS)
    end

    def chart_data?(ratings, weakness, performance)
      ratings.values.any? { |series| series.size >= 2 } ||
        weakness.size >= 2 ||
        performance[:blunders_per_game].size >= 2 ||
        performance[:average_centipawn_loss].size >= 2
    end
  end
end
