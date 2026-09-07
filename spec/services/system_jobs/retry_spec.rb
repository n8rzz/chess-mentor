# frozen_string_literal: true

require "rails_helper"

RSpec.describe SystemJobs::Retry do
  let(:user) { create(:user) }

  it "resets a retryable failed job to pending" do
    job = create(:system_job, :failed, user: user, attempts_count: 1, error_message: "boom")

    described_class.call(job: job)

    job.reload
    expect(job).to be_pending
    expect(job.error_message).to be_nil
    expect(job.finished_at).to be_nil
    expect(job.attempts_count).to eq(1)
  end

  it "can refresh the payload while retrying" do
    job = create(
      :system_job,
      :failed,
      user: user,
      attempts_count: 1,
      payload: { "import_batch_id" => "01OLD" }
    )

    described_class.call(
      job: job,
      payload: { "import_batch_id" => "01OLD", "access_token" => "fresh-token" }
    )

    expect(job.reload.payload).to eq(
      "import_batch_id" => "01OLD",
      "access_token" => "fresh-token"
    )
  end

  it "raises when the job is not retryable" do
    job = create(:system_job, :failed, user: user, attempts_count: SystemJob::MAX_ATTEMPTS)

    expect { described_class.call(job: job) }
      .to raise_error(SystemJobs::Retry::NotRetryableError, /not retryable/)
  end
end
