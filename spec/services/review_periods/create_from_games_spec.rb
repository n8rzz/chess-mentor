# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReviewPeriods::CreateFromGames do
  let(:user) { create(:user) }
  let(:provider_account) { create(:provider_account, user: user) }
  let!(:older_game) { create(:game, user: user, provider_account: provider_account, played_at: 10.days.ago) }
  let!(:newer_game) { create(:game, user: user, provider_account: provider_account, played_at: 2.days.ago) }

  it "creates a review period with game membership" do
    period = described_class.call(user: user, games: [ older_game, newer_game ])

    expect(period).to be_persisted
    expect(period.user).to eq(user)
    expect(period.games).to contain_exactly(older_game, newer_game)
    expect(period.starts_at).to be_within(1.second).of(older_game.played_at)
    expect(period.ends_at).to be_within(1.second).of(newer_game.played_at)
    expect(period.label).to include(older_game.played_at.to_date.to_s)
  end

  it "scopes games to the user" do
    other_game = create(:game)

    expect do
      described_class.call(user: user, games: [ other_game ])
    end.to raise_error(ReviewPeriods::CreateFromGames::EmptyGamesError)
  end
end
