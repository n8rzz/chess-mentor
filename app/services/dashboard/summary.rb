# frozen_string_literal: true

module Dashboard
  class Summary
    RATING_TIME_CLASSES = %i[bullet blitz rapid classical].freeze

    Result = Data.define(
      :ratings_by_time_class,
      :analysis_status,
      :training_today
    )

    AnalysisStatus = Data.define(:pending, :running, :succeeded, :failed, :total_games)

    TrainingToday = Data.define(
      :plan,
      :assignments_total,
      :assignments_completed,
      :assignments_due_overdue
    )

    def self.call(user:, active_plan: nil)
      new(user:, active_plan:).call
    end

    def initialize(user:, active_plan: nil)
      @user = user
      @active_plan = active_plan
    end

    def call
      Result.new(
        ratings_by_time_class: ratings_by_time_class,
        analysis_status: analysis_status,
        training_today: training_today
      )
    end

    private

    def ratings_by_time_class
      RATING_TIME_CLASSES.index_with do |time_class|
        @user.games
          .where(time_class:)
          .where.not(user_rating: nil)
          .order(played_at: :desc)
          .limit(1)
          .pick(:user_rating)
      end
    end

    def analysis_status
      counts = AnalysisRun.where(user_id: @user.id).group(:status).count
      AnalysisStatus.new(
        pending: counts.fetch("pending", 0),
        running: counts.fetch("running", 0),
        succeeded: counts.fetch("succeeded", 0) + counts.fetch("partially_succeeded", 0),
        failed: counts.fetch("failed", 0) + counts.fetch("cancelled", 0),
        total_games: @user.games.count
      )
    end

    def training_today
      plan = @active_plan
      return TrainingToday.new(plan: nil, assignments_total: 0, assignments_completed: 0, assignments_due_overdue: 0) if plan.blank?

      today_assignments = plan.assignments_for_today
      TrainingToday.new(
        plan:,
        assignments_total: today_assignments.count,
        assignments_completed: today_assignments.completed.count,
        assignments_due_overdue: plan.due_assignments.count
      )
    end
  end
end
