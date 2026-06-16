# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dashboard::Summary do
  describe ".call" do
    it "returns latest ratings by time class" do
      user = create(:user)
      provider_account = create(:provider_account, user:)
      import_batch = create(:import_batch, user:, provider_account:)
      create(:game, user:, provider_account:, import_batch:, time_class: :blitz, user_rating: 1500, played_at: 2.days.ago)
      create(:game, user:, provider_account:, import_batch:, time_class: :blitz, user_rating: 1520, played_at: 1.day.ago)
      create(:game, user:, provider_account:, import_batch:, time_class: :rapid, user_rating: 1600, played_at: 1.day.ago)

      result = described_class.call(user:)

      expect(result.ratings_by_time_class[:blitz]).to eq(1520)
      expect(result.ratings_by_time_class[:rapid]).to eq(1600)
      expect(result.ratings_by_time_class[:bullet]).to be_nil
    end

    it "summarizes analysis run status counts" do
      user = create(:user)
      provider_account = create(:provider_account, user:)
      import_batch = create(:import_batch, user:, provider_account:)
      game = create(:game, user:, provider_account:, import_batch:)
      create(:analysis_run, user:, game:, status: :pending)
      create(:analysis_run, user:, game: create(:game, user:, provider_account:, import_batch:), status: :succeeded)
      create(:analysis_run, user:, game: create(:game, user:, provider_account:, import_batch:), status: :failed)

      result = described_class.call(user:)

      expect(result.analysis_status.pending).to eq(1)
      expect(result.analysis_status.succeeded).to eq(1)
      expect(result.analysis_status.failed).to eq(1)
      expect(result.analysis_status.total_games).to eq(3)
    end

    it "summarizes today's training assignments for the active plan" do
      user = create(:user)
      plan = create(:training_plan, :active, user:)
      create(:training_assignment, training_plan: plan, due_on: Date.current, status: :completed)
      create(:training_assignment, training_plan: plan, due_on: Date.current, status: :pending)
      create(:training_assignment, training_plan: plan, due_on: Date.current - 1.day, status: :pending)

      result = described_class.call(user:, active_plan: plan)

      expect(result.training_today.assignments_total).to eq(2)
      expect(result.training_today.assignments_completed).to eq(1)
      expect(result.training_today.assignments_due_overdue).to eq(2)
    end
  end
end
