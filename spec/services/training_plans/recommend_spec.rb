# frozen_string_literal: true

require "rails_helper"

RSpec.describe TrainingPlans::Recommend do
  let(:user) { create(:user) }

  it "returns top three eligible weakness cycles by severity" do
    high = create(:pattern_cycle, :active, user: user, current_severity: 90, current_occurrences: 8)
    mid = create(:pattern_cycle, :detected, user: user, current_severity: 70, current_occurrences: 5)
    low = create(:pattern_cycle, :improving, user: user, current_severity: 50, current_occurrences: 4)
    create(:pattern_cycle, :managed, user: user, current_severity: 99)
    create(:pattern_cycle, :active, user: create(:user), current_severity: 100)

    recommendations = described_class.call(user: user)

    expect(recommendations).to eq([ high, mid, low ])
  end

  it "returns none when the user already has an active plan" do
    create(:pattern_cycle, :active, user: user, current_severity: 90)
    create(:training_plan, :active, user: user)

    expect(described_class.call(user: user)).to be_empty
  end

  it "returns none when the user has a paused plan" do
    create(:pattern_cycle, :active, user: user, current_severity: 90)
    create(:training_plan, user: user, status: :paused)

    expect(described_class.call(user: user)).to be_empty
  end
end
