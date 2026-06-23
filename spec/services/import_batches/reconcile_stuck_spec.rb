# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImportBatches::ReconcileStuck do
  let(:user) { create(:user) }
  let(:provider_account) { create(:provider_account, user: user) }

  describe ".call" do
    it "retries a failed import job for an in-progress batch" do
      batch = create(:import_batch, :running, user: user, provider_account: provider_account)
      job = create(
        :system_job,
        :import_games,
        :failed,
        user: user,
        payload: { "import_batch_id" => batch.id },
        attempts_count: 1
      )

      described_class.call

      expect(job.reload).to be_pending
    end

    it "enqueues a new import job for a stuck running batch without an active job" do
      batch = create(
        :import_batch,
        :running,
        user: user,
        provider_account: provider_account,
        started_at: 1.hour.ago
      )

      expect do
        described_class.call
      end.to change(SystemJob.import_games.pending, :count).by(1)

      job = SystemJob.import_games.pending.last
      expect(job.payload["import_batch_id"]).to eq(batch.id)
    end

    it "does not enqueue when a pending import job already exists" do
      batch = create(:import_batch, :running, user: user, provider_account: provider_account, started_at: 1.hour.ago)
      create(
        :system_job,
        :import_games,
        user: user,
        payload: { "import_batch_id" => batch.id }
      )

      expect do
        described_class.call
      end.not_to change(SystemJob.import_games.pending, :count)
    end

    it "does not enqueue for a recently started running batch" do
      create(
        :import_batch,
        :running,
        user: user,
        provider_account: provider_account,
        started_at: 5.minutes.ago
      )

      expect do
        described_class.call
      end.not_to change(SystemJob.import_games.pending, :count)
    end

    it "does not retry a failed import job when the batch is already failed" do
      batch = create(:import_batch, :failed, user: user, provider_account: provider_account)
      job = create(
        :system_job,
        :import_games,
        :failed,
        user: user,
        payload: { "import_batch_id" => batch.id },
        attempts_count: 1
      )

      described_class.call

      expect(job.reload).to be_failed
    end

    it "does not enqueue for a stuck batch when the provider account has no access token" do
      account = create(:provider_account, user: user, access_token: nil)
      create(
        :import_batch,
        :running,
        user: user,
        provider_account: account,
        started_at: 1.hour.ago
      )

      expect do
        described_class.call
      end.not_to change(SystemJob.import_games.pending, :count)
    end

    it "does not retry a failed import job when the provider account has no access token" do
      account = create(:provider_account, user: user, access_token: nil)
      batch = create(:import_batch, :running, user: user, provider_account: account)
      job = create(
        :system_job,
        :import_games,
        :failed,
        user: user,
        payload: { "import_batch_id" => batch.id },
        attempts_count: 1
      )

      described_class.call

      expect(job.reload).to be_failed
    end
  end
end
