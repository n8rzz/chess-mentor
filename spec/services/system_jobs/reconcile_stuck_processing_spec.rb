# frozen_string_literal: true

require "rails_helper"

RSpec.describe SystemJobs::ReconcileStuckProcessing do
  let(:user) { create(:user) }

  def with_timeout_env(value)
    key = "SYSTEM_JOB_STUCK_TIMEOUT_ANALYZE_GAME_SECONDS"
    previous = ENV[key]
    ENV[key] = value
    yield
  ensure
    if previous.nil?
      ENV.delete(key)
    else
      ENV[key] = previous
    end
  end

  def age_job!(job, age:)
    timestamp = age.ago
    job.update_columns(
      started_at: timestamp,
      created_at: timestamp,
      updated_at: timestamp
    )
  end

  it "fails and retries a stale processing analyze_game job" do
    with_timeout_env("60") do
      game = create(:game, user: user)
      run = create(:analysis_run, game: game, user: user, status: :pending)
      job = create(
        :system_job,
        :analyze_game,
        :processing,
        user: user,
        attempts_count: 1,
        payload: { "analysis_run_id" => run.id, "game_id" => game.id }
      )
      age_job!(job, age: 2.hours)

      described_class.call

      job.reload
      expect(job).to be_pending
      expect(job.attempts_count).to eq(1)
      expect(run.reload).to be_pending
    end
  end

  it "leaves a recently heartbeated processing job alone" do
    with_timeout_env("60") do
      job = create(
        :system_job,
        :analyze_game,
        :processing,
        user: user,
        attempts_count: 1
      )
      job.update_columns(started_at: 2.hours.ago, updated_at: 10.seconds.ago)

      described_class.call

      expect(job.reload).to be_processing
    end
  end

  it "marks the analysis run failed when retries are exhausted" do
    with_timeout_env("60") do
      game = create(:game, user: user)
      run = create(:analysis_run, game: game, user: user, status: :pending)
      job = create(
        :system_job,
        :analyze_game,
        :processing,
        user: user,
        attempts_count: SystemJob::MAX_ATTEMPTS,
        payload: { "analysis_run_id" => run.id, "game_id" => game.id }
      )
      age_job!(job, age: 2.hours)

      described_class.call

      expect(job.reload).to be_failed
      expect(job.error_details["code"]).to eq("stuck_processing")
      expect(run.reload).to be_failed
      expect(run.error_message).to match(/exhausted retries/)
    end
  end

  it "fails and retries a stale processing import_games job" do
    previous = ENV["SYSTEM_JOB_STUCK_TIMEOUT_IMPORT_GAMES_SECONDS"]
    ENV["SYSTEM_JOB_STUCK_TIMEOUT_IMPORT_GAMES_SECONDS"] = "60"
    begin
      job = create(
        :system_job,
        :processing,
        user: user,
        attempts_count: 1,
        payload: { "import_batch_id" => "01IMPORTBATCH" }
      )
      age_job!(job, age: 2.hours)

      described_class.call

      expect(job.reload).to be_pending
      expect(job.error_message).to be_nil
    ensure
      if previous.nil?
        ENV.delete("SYSTEM_JOB_STUCK_TIMEOUT_IMPORT_GAMES_SECONDS")
      else
        ENV["SYSTEM_JOB_STUCK_TIMEOUT_IMPORT_GAMES_SECONDS"] = previous
      end
    end
  end
end
