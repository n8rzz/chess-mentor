# frozen_string_literal: true

require "rails_helper"

RSpec.describe SystemJobs::Create do
  let(:user) { create(:user) }

  describe ".call" do
    it "creates a pending system job with stringified payload keys" do
      job = described_class.call(
        user: user,
        job_type: :import_games,
        payload: { import_batch_id: "01BATCH", dry_run: true }
      )

      expect(job).to be_persisted
      expect(job).to be_pending
      expect(job.user).to eq(user)
      expect(job.job_type).to eq("import_games")
      expect(job.payload).to eq("import_batch_id" => "01BATCH", "dry_run" => true)
      expect(job.attempts_count).to eq(0)
      expect(job.result).to be_nil
    end

    it "defaults payload to an empty hash" do
      job = described_class.call(user: user, job_type: :classify_weaknesses)

      expect(job.payload).to eq({})
    end

    it "raises when payload is not a hash" do
      expect do
        described_class.call(user: user, job_type: :import_games, payload: "nope")
      end.to raise_error(ArgumentError, /Hash/)
    end

    it "raises when job_type is invalid" do
      expect do
        described_class.call(user: user, job_type: :not_a_job_type)
      end.to raise_error(ActiveRecord::RecordInvalid, /Job type/)
    end

    it "enqueues each documented job type" do
      SystemJob.job_types.each_key do |job_type|
        job = described_class.call(user: user, job_type: job_type)

        expect(job).to be_pending
        expect(job.job_type).to eq(job_type)
      end
    end
  end
end
