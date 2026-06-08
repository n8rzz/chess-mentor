# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnalysisRuns::BulkEnqueueForImport do
  let(:user) { create(:user) }
  let(:provider_account) { create(:provider_account, user: user) }
  let(:import_batch) do
    create(
      :import_batch,
      :succeeded,
      user: user,
      provider_account: provider_account,
      metadata: {}
    )
  end

  describe ".call" do
    it "creates analysis runs and jobs for imported games" do
      game = create(:game, user: user, provider_account: provider_account, import_batch: import_batch)
      create(
        :import_record,
        import_batch: import_batch,
        provider: :lichess,
        provider_game_id: game.provider_game_id,
        status: :imported,
        game: game
      )

      expect do
        described_class.call(import_batch: import_batch)
      end.to change(AnalysisRun, :count).by(1)
        .and change(SystemJob, :count).by(1)

      expect(import_batch.reload.metadata["analysis_enqueued_at"]).to be_present
    end

    it "is idempotent" do
      game = create(:game, user: user, provider_account: provider_account, import_batch: import_batch)
      create(
        :import_record,
        import_batch: import_batch,
        provider: :lichess,
        provider_game_id: game.provider_game_id,
        status: :imported,
        game: game
      )

      described_class.call(import_batch: import_batch)

      expect do
        described_class.call(import_batch: import_batch.reload)
      end.not_to change(SystemJob, :count)
    end

    it "does nothing for pending batches" do
      batch = create(:import_batch, user: user, provider_account: provider_account)

      expect do
        described_class.call(import_batch: batch)
      end.not_to change(AnalysisRun, :count)
    end

    it "enqueues analysis for partially succeeded batches" do
      batch = create(
        :import_batch,
        status: :partially_succeeded,
        user: user,
        provider_account: provider_account,
        metadata: {}
      )
      game = create(:game, user: user, provider_account: provider_account, import_batch: batch)
      create(
        :import_record,
        import_batch: batch,
        provider: :lichess,
        provider_game_id: game.provider_game_id,
        status: :imported,
        game: game
      )

      expect do
        described_class.call(import_batch: batch)
      end.to change(AnalysisRun, :count).by(1)
    end

    it "skips games that already have an in-progress analysis run" do
      game = create(:game, user: user, provider_account: provider_account, import_batch: import_batch)
      create(
        :import_record,
        import_batch: import_batch,
        provider: :lichess,
        provider_game_id: game.provider_game_id,
        status: :imported,
        game: game
      )
      create(:analysis_run, :running, game: game, user: user)

      expect do
        described_class.call(import_batch: import_batch)
      end.not_to change(AnalysisRun, :count)
    end
  end
end
