# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SystemJob worker contract", type: :integration do
  include SystemJobWorkerContract

  let(:user) { create(:user) }
  let(:worker_id) { "worker-test" }

  it "maps Rails enums to the documented integer contract" do
    expect(SystemJob.statuses).to eq(
      "pending" => 0,
      "claimed" => 1,
      "processing" => 2,
      "succeeded" => 3,
      "failed" => 4,
      "cancelled" => 5
    )
    expect(SystemJob.job_types).to eq(
      "import_games" => 0,
      "analyze_game" => 1,
      "classify_weaknesses" => 2,
      "generate_training_plan" => 3,
      "update_progress_snapshots" => 4
    )
  end

  it "claims the oldest pending job and completes the success path" do
    job = SystemJobs::Create.call(
      user: user,
      job_type: :import_games,
      payload: { "dry_run" => true }
    )

    claimed = claim_next_job(worker_id: worker_id)

    expect(claimed.id).to eq(job.id)
    expect(claimed).to be_processing
    expect(claimed.claimed_by).to eq(worker_id)
    expect(claimed.attempts_count).to eq(1)
    expect(claimed.started_at).to be_present

    mark_succeeded(claimed, { "stub" => true, "job_type" => "import_games" })
    claimed.reload

    expect(claimed).to be_succeeded
    expect(claimed.result).to eq("stub" => true, "job_type" => "import_games")
    expect(claimed.finished_at).to be_present
  end

  it "claims jobs in created_at order" do
    older = SystemJobs::Create.call(user: user, job_type: :import_games, payload: { "order" => "older" })
    older.update_column(:created_at, 2.minutes.ago)

    newer = SystemJobs::Create.call(user: user, job_type: :analyze_game, payload: { "order" => "newer" })

    first_claim = claim_next_job(worker_id: worker_id)
    mark_succeeded(first_claim, { "stub" => true })

    second_claim = claim_next_job(worker_id: worker_id)

    expect(first_claim.id).to eq(older.id)
    expect(second_claim.id).to eq(newer.id)
  end

  it "records failures on the failed path" do
    job = SystemJobs::Create.call(user: user, job_type: :classify_weaknesses)
    claimed = claim_next_job(worker_id: worker_id)

    mark_failed(claimed, "handler error", details: { "code" => "handler_error" })
    claimed.reload

    expect(claimed).to be_failed
    expect(claimed.error_message).to eq("handler error")
    expect(claimed.error_details).to eq("code" => "handler_error")
    expect(claimed.finished_at).to be_present
    expect(job.reload).to be_failed
  end
end
