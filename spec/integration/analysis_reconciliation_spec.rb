# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Analysis reconciliation", type: :integration do
  let(:user) { create(:user) }
  let(:provider_account) { create(:provider_account, user: user) }
  let(:import_batch) do
    create(:import_batch, :succeeded, user: user, provider_account: provider_account, metadata: {})
  end

  def create_imported_game(batch:, opponent:)
    game = create(
      :game,
      user: user,
      provider_account: provider_account,
      import_batch: batch,
      opponent_username: opponent
    )
    create(
      :import_record,
      import_batch: batch,
      provider: :lichess,
      provider_game_id: game.provider_game_id,
      status: :imported,
      game: game
    )
    game
  end

  describe "ReconcileAll with BulkEnqueueForImport" do
    it "enqueues analysis for every imported game in a batch" do
      games = 3.times.map { |index| create_imported_game(batch: import_batch, opponent: "rival_#{index}") }

      expect do
        AnalysisRuns::ReconcileAll.call
      end.to change(AnalysisRun, :count).by(3)
        .and change(SystemJob.where(job_type: :analyze_game), :count).by(3)

      expect(import_batch.reload.metadata["analysis_enqueued_at"]).to be_present

      games.each do |game|
        run = AnalysisRun.find_by!(game: game)
        expect(run).to be_pending

        job = SystemJob.analyze_game.find_by!("payload->>'analysis_run_id' = ?", run.id)
        expect(job.payload["game_id"]).to eq(game.id)
        expect(job.user_id).to eq(user.id)
      end
    end

    it "is idempotent across a multi-game batch" do
      2.times { |index| create_imported_game(batch: import_batch, opponent: "rival_#{index}") }

      AnalysisRuns::ReconcileAll.call

      run_count = AnalysisRun.count
      job_count = SystemJob.count

      AnalysisRuns::ReconcileAll.call

      expect(AnalysisRun.count).to eq(run_count)
      expect(SystemJob.count).to eq(job_count)
    end

    it "skips games that already have an in-progress analysis run" do
      games = 2.times.map { |index| create_imported_game(batch: import_batch, opponent: "rival_#{index}") }
      create(:analysis_run, :running, game: games.first, user: user)

      expect do
        AnalysisRuns::ReconcileAll.call
      end.to change(AnalysisRun, :count).by(1)
        .and change(SystemJob.where(job_type: :analyze_game), :count).by(1)

      expect(AnalysisRun.find_by(game: games.first)).to be_running
      expect(AnalysisRun.find_by(game: games.second)).to be_pending
    end
  end
end
