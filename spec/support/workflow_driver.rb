# frozen_string_literal: true

class WorkflowDriver
  include PythonPipelineHelpers

  ACTIVE_JOB_STATUSES = %i[pending claimed processing].freeze
  MAX_DRAIN_ITERATIONS = 100

  def initialize(worker_id: "workflow-test")
    @worker_id = worker_id
  end

  def drain_pending_jobs!(limit: MAX_DRAIN_ITERATIONS)
    processed = 0

    while (job = SystemJob.pending.order(:created_at).first) && processed < limit
      process_job!(job)
      processed += 1
    end

    processed
  end

  def process_job!(job)
    result = dispatch_job(job)
    job.update!(
      status: :succeeded,
      result: result,
      finished_at: Time.current,
      error_message: nil,
      error_details: {}
    )
  rescue StandardError => error
    job.update!(
      status: :failed,
      error_message: error.message,
      error_details: { "code" => "workflow_driver_error" },
      finished_at: Time.current
    )
    raise
  end

  def run_post_import_pipeline!
    AnalysisRuns::ReconcileAll.call
    drain_pending_jobs!
  end

  def wait_for_import_batch!(batch, status:, timeout: Capybara.default_max_wait_time)
    deadline = Time.current + timeout

    loop do
      batch.reload
      return batch if batch.status == status.to_s

      raise "Import batch did not reach #{status} within #{timeout}s (current: #{batch.status})" if Time.current >= deadline

      sleep 0.05
    end
  end

  def wait_for_training_plan_assignments!(plan, timeout: Capybara.default_max_wait_time)
    deadline = Time.current + timeout

    loop do
      plan.reload
      return plan if plan.training_assignments.any?

      drain_pending_jobs!
      raise "Training plan assignments not generated within #{timeout}s" if Time.current >= deadline

      sleep 0.05
    end
  end

  private

  def dispatch_job(job)
    case job.job_type
    when "import_games"
      import_batch_id = job.payload.fetch("import_batch_id")
      run_python_import(import_batch_id: import_batch_id)
      ImportBatch.find(import_batch_id).attributes.slice(
        "status", "games_found_count", "games_imported_count", "games_skipped_count", "games_failed_count"
      )
    when "analyze_game"
      run_python_analysis(
        analysis_run_id: job.payload.fetch("analysis_run_id"),
        game_id: job.payload.fetch("game_id")
      )
    when "classify_patterns"
      user_id = job.payload["user_id"] || job.user_id
      run_python_classification(user_id: user_id)
    when "generate_training_plan"
      run_python_plan_generation(training_plan_id: job.payload.fetch("training_plan_id"))
    when "update_progress_snapshots"
      user_id = job.payload["user_id"] || job.user_id
      run_python_progress_snapshots(user_id: user_id)
    else
      raise ArgumentError, "unsupported job type: #{job.job_type}"
    end
  end
end

RSpec.configure do |config|
  config.include(Module.new do
    def workflow_driver
      @workflow_driver ||= WorkflowDriver.new
    end
  end)
end
