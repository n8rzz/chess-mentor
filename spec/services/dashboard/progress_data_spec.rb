# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dashboard::ProgressData do
  describe ".call" do
    it "groups snapshot series by kind and time class" do
      user = create(:user)
      plan = create(:training_plan, :active, user:)
      cycle = plan.pattern_cycle
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
        pattern_cycle: cycle,
        pattern_frequency: 0.5,
        pattern_severity: 0.6,
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
      expect(result.chart_status).to eq(:ready)
    end

    it "dedupes multiple snapshots from the same day" do
      user = create(:user)
      day = Time.zone.local(2026, 6, 22, 10, 0)

      2.times do |index|
        create(
          :progress_snapshot,
          user:,
          blunders_per_game: 1.0 - (index * 0.1),
          snapshot_at: day + index.hours,
          metadata: { "kind" => "performance" }
        )
      end
      create(
        :progress_snapshot,
        user:,
        blunders_per_game: 0.5,
        snapshot_at: day - 1.day,
        metadata: { "kind" => "performance" }
      )

      result = described_class.call(user:)

      expect(result.blunders_per_game.map(&:value)).to eq([ 0.5, 0.9 ])
    end

    it "reports no snapshots when none exist" do
      user = create(:user)

      result = described_class.call(user:)

      expect(result.chart_status).to eq(:none)
    end

    it "reports insufficient days when snapshots exist on only one day" do
      user = create(:user)
      now = Time.current

      2.times do |index|
        create(
          :progress_snapshot,
          user:,
          time_class: :blitz,
          rating: 1500 + index,
          snapshot_at: now + index.minutes,
          metadata: { "kind" => "rating" }
        )
      end

      result = described_class.call(user:)

      expect(result.chart_status).to eq(:insufficient_days)
    end
  end
end
