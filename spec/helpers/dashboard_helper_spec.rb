# frozen_string_literal: true

require "rails_helper"

RSpec.describe DashboardHelper, type: :helper do
  include described_class

  describe "#format_chart_label" do
    it "formats timestamps as month and day" do
      timestamp = Time.zone.local(2026, 6, 22, 14, 30)

      expect(format_chart_label(timestamp)).to eq("Jun 22")
    end
  end

  describe "#dashboard_chart_cards" do
    it "returns no cards when progress spans only one day" do
      user = create(:user)
      plan = create(:training_plan, :active, user: user)
      cycle = plan.weakness_cycle
      base = Time.zone.local(2026, 6, 22, 10, 0)

      3.times do |index|
        snapshot_at = base + (index * 2).hours
        create(
          :progress_snapshot,
          user:,
          weakness_cycle: cycle,
          weakness_frequency: 0.5 - (index * 0.05),
          snapshot_at:,
          metadata: { "kind" => "weakness", "current_occurrences" => 4 - index }
        )
        create(
          :progress_snapshot,
          user:,
          time_class: :blitz,
          rating: 1500 + index,
          snapshot_at:,
          metadata: { "kind" => "rating" }
        )
        create(
          :progress_snapshot,
          user:,
          blunders_per_game: 1.0,
          average_centipawn_loss: 40.0,
          games_analyzed_count: 10,
          snapshot_at:,
          metadata: { "kind" => "performance" }
        )
      end

      progress = Dashboard::ProgressData.call(user: user, active_plan: plan)

      expect(progress.chart_status).to eq(:insufficient_days)
      expect(dashboard_chart_cards(progress)).to eq([])
    end

    it "returns cards when progress spans multiple days" do
      user = create(:user)
      plan = create(:training_plan, :active, user: user)
      cycle = plan.weakness_cycle

      2.times do |index|
        snapshot_at = (index + 1).days.ago
        create(
          :progress_snapshot,
          user:,
          weakness_cycle: cycle,
          weakness_frequency: 0.5,
          snapshot_at:,
          metadata: { "kind" => "weakness", "current_occurrences" => 4 - index }
        )
        create(
          :progress_snapshot,
          user:,
          time_class: :blitz,
          rating: 1500 + (index * 20),
          snapshot_at:,
          metadata: { "kind" => "rating" }
        )
        create(
          :progress_snapshot,
          user:,
          blunders_per_game: 1.0 - (index * 0.1),
          average_centipawn_loss: 40.0 - index,
          games_analyzed_count: 10,
          snapshot_at:,
          metadata: { "kind" => "performance" }
        )
      end

      progress = Dashboard::ProgressData.call(user: user, active_plan: plan)

      expect(progress.chart_status).to eq(:ready)

      cards = dashboard_chart_cards(progress)

      expect(cards.map { |card| card[:key] }).to include("weakness_trend", "blunders")
      expect(cards.find { |card| card[:key] == "rating_history" }[:integer_y_axis]).to be(true)
    end
  end
end
