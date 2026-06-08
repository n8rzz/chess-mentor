# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnalysisRuns::ReconcileAll do
  let(:user) { create(:user) }
  let(:provider_account) { create(:provider_account, user: user) }
  let(:import_batch) do
    create(:import_batch, :succeeded, user: user, provider_account: provider_account, metadata: {})
  end

  describe ".call" do
    it "enqueues analysis for succeeded import batches that were never processed" do
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
        described_class.call
      end.to change(AnalysisRun, :count).by(1)
        .and change(SystemJob.where(job_type: :analyze_game), :count).by(1)

      expect(import_batch.reload.metadata["analysis_enqueued_at"]).to be_present
    end

    it "re-enqueues analyze_game jobs for pending runs left behind by stub handlers" do
      game = create(:game, user: user, provider_account: provider_account, import_batch: import_batch)
      run = create(:analysis_run, game: game, user: user, status: :pending)
      create(
        :system_job,
        :analyze_game,
        :succeeded,
        user: user,
        payload: { "analysis_run_id" => run.id, "game_id" => game.id },
        result: { "stub" => true }
      )

      expect do
        described_class.call
      end.to change(SystemJob.where(job_type: :analyze_game, status: :pending), :count).by(1)
    end

    it "does not duplicate jobs when a pending analyze_game job already exists" do
      game = create(:game, user: user, provider_account: provider_account, import_batch: import_batch)
      run = create(:analysis_run, game: game, user: user, status: :pending)
      create(
        :system_job,
        :analyze_game,
        user: user,
        payload: { "analysis_run_id" => run.id, "game_id" => game.id }
      )

      expect do
        described_class.call
      end.not_to change(SystemJob, :count)
    end

    %i[claimed processing].each do |active_status|
      it "does not re-enqueue when a #{active_status} analyze_game job is in progress" do
        game = create(:game, user: user, provider_account: provider_account, import_batch: import_batch)
        run = create(:analysis_run, game: game, user: user, status: :pending)
        create(
          :system_job,
          :analyze_game,
          active_status,
          user: user,
          payload: { "analysis_run_id" => run.id, "game_id" => game.id }
        )

        expect do
          described_class.call
        end.not_to change(SystemJob, :count)
      end
    end

    it "enqueues analysis for partially_succeeded import batches that were never processed" do
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
        described_class.call
      end.to change(AnalysisRun, :count).by(1)
        .and change(SystemJob.where(job_type: :analyze_game), :count).by(1)

      expect(batch.reload.metadata["analysis_enqueued_at"]).to be_present
    end

    it "does not re-enqueue succeeded analysis runs" do
      game = create(:game, user: user, provider_account: provider_account, import_batch: import_batch)
      create(:analysis_run, :succeeded, game: game, user: user)

      expect do
        described_class.call
      end.not_to change(SystemJob.where(job_type: :analyze_game), :count)
    end

    it "creates analysis runs and jobs for games missing runs" do
      game = create(:game, user: user, provider_account: provider_account, import_batch: import_batch)

      expect do
        described_class.call
      end.to change(AnalysisRun, :count).by(1)
        .and change(SystemJob.where(job_type: :analyze_game), :count).by(1)

      expect(AnalysisRun.find_by(game: game)).to be_pending
    end
  end
end
