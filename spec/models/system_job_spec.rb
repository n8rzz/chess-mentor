# frozen_string_literal: true

# == Schema Information
#
# Table name: system_jobs
#
#  id             :string           not null, primary key
#  attempts_count :integer          default(0), not null
#  claimed_by     :string
#  error_details  :jsonb
#  error_message  :text
#  finished_at    :datetime
#  job_type       :integer          not null
#  payload        :jsonb            not null
#  result         :jsonb
#  started_at     :datetime
#  status         :integer          default("pending"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :string           not null
#
# Indexes
#
#  index_system_jobs_on_status_and_created_at   (status,created_at)
#  index_system_jobs_on_user_id                 (user_id)
#  index_system_jobs_on_user_id_and_created_at  (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe SystemJob, type: :model do
  subject(:system_job) { build(:system_job) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "enums" do
    it do
      expect(system_job).to define_enum_for(:job_type)
        .with_values(
          import_games: 0,
          analyze_game: 1,
          classify_weaknesses: 2,
          generate_training_plan: 3,
          update_progress_snapshots: 4
        )
        .backed_by_column_of_type(:integer)
    end

    it do
      expect(system_job).to define_enum_for(:status)
        .with_values(
          pending: 0,
          claimed: 1,
          processing: 2,
          succeeded: 3,
          failed: 4,
          cancelled: 5
        )
        .backed_by_column_of_type(:integer)
        .with_default(:pending)
    end
  end

  describe "validations" do
    it "allows an empty hash payload" do
      expect(build(:system_job, payload: {})).to be_valid
    end

    it "requires payload to be a hash" do
      system_job.payload = "not-a-hash"

      expect(system_job).not_to be_valid
      expect(system_job.errors[:payload]).to include("must be a hash")
    end

    it "prevents updates to terminal jobs" do
      job = create(:system_job, :succeeded)

      job.payload = { "updated" => true }

      expect(job).not_to be_valid
      expect(job.errors[:base]).to include("terminal jobs cannot be modified")
    end

    %i[failed cancelled].each do |terminal_trait|
      it "prevents updates to #{terminal_trait} jobs" do
        job = create(:system_job, terminal_trait)

        job.error_message = "changed"

        expect(job).not_to be_valid
        expect(job.errors[:base]).to include("terminal jobs cannot be modified")
      end
    end
  end

  describe "scopes" do
    it "in_progress includes claimed and processing" do
      pending = create(:system_job)
      claimed = create(:system_job, :claimed)
      processing = create(:system_job, :processing)
      create(:system_job, :succeeded)

      expect(described_class.in_progress).to contain_exactly(claimed, processing)
      expect(described_class.pending).to contain_exactly(pending)
    end

    it "terminal includes succeeded, failed, and cancelled" do
      succeeded = create(:system_job, :succeeded)
      failed = create(:system_job, :failed)
      cancelled = create(:system_job, :cancelled)
      create(:system_job)

      expect(described_class.terminal).to contain_exactly(succeeded, failed, cancelled)
    end
  end

  describe "#cancel!" do
    it "cancels a pending job" do
      job = create(:system_job)

      job.cancel!

      expect(job).to be_cancelled
      expect(job.finished_at).to be_present
    end

    it "raises when the job is not pending" do
      job = create(:system_job, :processing)

      expect { job.cancel! }.to raise_error(ArgumentError, /pending/)
    end
  end

  describe "#retryable?" do
    it "is true for failed jobs under max attempts" do
      job = create(:system_job, :failed, attempts_count: 1)

      expect(job).to be_retryable
    end

    it "is false when attempts exhausted" do
      job = create(:system_job, :failed, attempts_count: SystemJob::MAX_ATTEMPTS)

      expect(job).not_to be_retryable
    end

    it "is false for non-failed jobs" do
      expect(build(:system_job)).not_to be_retryable
    end
  end
end
