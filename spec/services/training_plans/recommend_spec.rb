# frozen_string_literal: true

require "rails_helper"

RSpec.describe TrainingPlans::Recommend do
  let(:user) { create(:user) }

  it "returns top three eligible weakness cycles by severity" do
    high = create(:weakness_cycle, :active, user: user, current_severity: 90, current_occurrences: 8)
    mid = create(:weakness_cycle, :detected, user: user, current_severity: 70, current_occurrences: 5)
    low = create(:weakness_cycle, :improving, user: user, current_severity: 50, current_occurrences: 4)
    create(:weakness_cycle, :managed, user: user, current_severity: 99)
    create(:weakness_cycle, :active, user: create(:user), current_severity: 100)

    recommendations = described_class.call(user: user)

    expect(recommendations).to eq([ high, mid, low ])
  end

  it "returns none when the user already has an active plan" do
    create(:weakness_cycle, :active, user: user, current_severity: 90)
    create(:training_plan, :active, user: user)

    expect(described_class.call(user: user)).to be_empty
  end

  it "returns none when the user has a paused plan" do
    create(:weakness_cycle, :active, user: user, current_severity: 90)
    create(:training_plan, user: user, status: :paused)

    expect(described_class.call(user: user)).to be_empty
  end
end
