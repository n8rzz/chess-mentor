# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dashboard::ProgressData do
  describe ".call" do
    it "groups snapshot series by kind and time class" do
      user = create(:user)
      plan = create(:training_plan, :active, user:)
      cycle = plan.weakness_cycle
      now = Time.current

      create(
        :progress_snapshot,
        user:,
        time_class: :blitz,
        rating: 1500,
        snapshot_at: 2.days.ago,
        metadata: { "kind" => "rating" }
      )
      create(
        :progress_snapshot,
        user:,
        time_class: :blitz,
        rating: 1520,
        snapshot_at: 1.day.ago,
        metadata: { "kind" => "rating" }
      )
      create(
        :progress_snapshot,
        user:,
        weakness_cycle: cycle,
        weakness_frequency: 0.5,
        weakness_severity: 0.6,
        snapshot_at: 1.day.ago,
        metadata: { "kind" => "weakness", "current_occurrences" => 3 }
      )
      create(
        :progress_snapshot,
        user:,
        blunders_per_game: 0.8,
        average_centipawn_loss: 42.5,
        games_analyzed_count: 10,
        snapshot_at: 1.day.ago,
        metadata: { "kind" => "performance" }
      )
      create(
        :progress_snapshot,
        user:,
        blunders_per_game: 0.6,
        average_centipawn_loss: 35.0,
        games_analyzed_count: 12,
        snapshot_at: now,
        metadata: { "kind" => "performance" }
      )

      result = described_class.call(user:, active_plan: plan)

      expect(result.ratings_by_time_class[:blitz].map(&:value)).to eq([ 1500, 1520 ])
      expect(result.weakness_trend.length).to eq(1)
      expect(result.weakness_trend.first.occurrences).to eq(3)
      expect(result.blunders_per_game.map(&:value)).to eq([ 0.8, 0.6 ])
      expect(result.average_centipawn_loss.map(&:value)).to eq([ 42.5, 35.0 ])
      expect(result.has_chart_data).to be(true)
    end

    it "reports no chart data when fewer than two points exist" do
      user = create(:user)
      create(
        :progress_snapshot,
        user:,
        time_class: :blitz,
        rating: 1500,
        metadata: { "kind" => "rating" }
      )

      result = described_class.call(user:)

      expect(result.has_chart_data).to be(false)
    end
  end
end
