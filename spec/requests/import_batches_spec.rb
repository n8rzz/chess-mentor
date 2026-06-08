# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Import batches", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /import_batches" do
    it "lists the current user's import batches" do
      account = create(:provider_account, user: user)
      batch = create(:import_batch, :succeeded, user: user, provider_account: account)
      other_account = create(:provider_account, user: other_user)
      create(:import_batch, :succeeded, user: other_user, provider_account: other_account)

      sign_in user
      get import_batches_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("succeeded")
      expect(response.body).to include(batch.games_imported_count.to_s)
    end
  end

  describe "GET /import_batches/new" do
    it "redirects when Lichess is not connected" do
      sign_in user

      get new_import_batch_path

      expect(response).to redirect_to(settings_providers_path)
    end

    it "renders the import form when Lichess is connected" do
      create(:provider_account, user: user)
      sign_in user

      get new_import_batch_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Start import")
    end
  end

  describe "POST /import_batches" do
    it "creates an import batch" do
      create(:provider_account, user: user)
      sign_in user

      expect do
        post import_batches_path, params: {
          import: { days: 7, time_controls: %w[blitz], max_games: 10 }
        }
      end.to change(ImportBatch, :count).by(1)
        .and change(SystemJob, :count).by(1)

      expect(response).to redirect_to(import_batch_path(ImportBatch.last))
    end

    it "redirects with an alert when an import is already in progress" do
      account = create(:provider_account, user: user)
      create(:import_batch, :running, user: user, provider_account: account)
      sign_in user

      post import_batches_path, params: {
        import: { days: 7, time_controls: %w[blitz], max_games: 10 }
      }

      expect(response).to redirect_to(new_import_batch_path)
      expect(flash[:alert]).to include("already in progress")
    end
  end

  describe "GET /import_batches/:id" do
    it "shows import status" do
      account = create(:provider_account, user: user)
      batch = create(:import_batch, :succeeded, user: user, provider_account: account, games_imported_count: 5)
      sign_in user

      get import_batch_path(batch)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("succeeded")
      expect(response.body).to include("5")
    end

    it "does not allow viewing another user's import batch" do
      account = create(:provider_account, user: other_user)
      batch = create(:import_batch, :succeeded, user: other_user, provider_account: account)
      sign_in user

      get import_batch_path(batch)

      expect(response).to have_http_status(:not_found)
    end

    it "queues analysis reconciliation when viewing a succeeded batch" do
      account = create(:provider_account, user: user)
      batch = create(
        :import_batch,
        :succeeded,
        user: user,
        provider_account: account,
        metadata: {}
      )
      sign_in user

      expect(AnalysisRuns::ReconcileJob).to receive(:perform_async).with(false)

      get import_batch_path(batch)
    end
  end
end
