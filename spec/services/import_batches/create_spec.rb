# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImportBatches::Create do
  let(:user) { create(:user) }
  let(:provider_account) { create(:provider_account, user: user) }

  describe ".call" do
    it "creates an import batch and enqueues a system job" do
      expect do
        described_class.call(
          user: user,
          provider_account: provider_account,
          days: 7,
          time_controls: %w[blitz rapid]
        )
      end.to change(ImportBatch, :count).by(1)
        .and change(SystemJob, :count).by(1)

      batch = ImportBatch.last
      job = SystemJob.last

      expect(batch).to be_pending
      expect(batch.provider).to eq("lichess")
      expect(batch.time_controls).to eq(%w[blitz rapid])
      expect(job.job_type).to eq("import_games")
      expect(job.payload).to eq("import_batch_id" => batch.id)
    end

    it "rejects a non-Lichess provider account" do
      chess_account = create(:provider_account, :chess_com, user: user)

      expect do
        described_class.call(
          user: user,
          provider_account: chess_account,
          days: 7,
          time_controls: %w[blitz]
        )
      end.to raise_error(ImportBatches::Create::InvalidProviderError)
    end

    it "rejects when an import is already in progress" do
      create(:import_batch, :running, user: user, provider_account: provider_account)

      expect do
        described_class.call(
          user: user,
          provider_account: provider_account,
          days: 7,
          time_controls: %w[blitz]
        )
      end.to raise_error(ImportBatches::Create::ImportInProgressError)
    end

    it "rejects invalid filters" do
      expect do
        described_class.call(
          user: user,
          provider_account: provider_account,
          days: 99,
          time_controls: %w[blitz]
        )
      end.to raise_error(ImportBatches::Create::InvalidFiltersError)
    end
  end
end
