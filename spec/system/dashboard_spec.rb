# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard", type: :system do
  let(:password) { "password123" }

  it "redirects email sign-up to the dashboard" do
    visit new_user_registration_path

    fill_in "Username", with: "newplayer"
    fill_in "Email", with: "newplayer@example.com"
    fill_in "Password", with: password
    fill_in "Password confirmation", with: password
    click_button "Sign up"

    expect(page).to have_current_path(dashboard_path)
    expect(page).to have_text("Dashboard")
    expect(page).to have_text("newplayer")
  end

  it "redirects email sign-in to the dashboard" do
    create(:user, username: "starship", email: "starship@example.com", password: password)

    visit new_user_session_path
    fill_in "Email", with: "starship@example.com"
    fill_in "Password", with: password
    click_button "Log in"

    expect(page).to have_current_path(dashboard_path)
    expect(page).to have_text("Signed in as")
    expect(page).to have_text("starship")
  end

  it "returns to the public home page after sign out" do
    user = create(:user, password: password)

    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Log in"

    click_button "Sign out"

    expect(page).to have_current_path(root_path)
    expect(page).to have_link("Sign in")
    expect(page).not_to have_text("Signed in as")
  end

  it "shows a linked Lichess account on the dashboard after OAuth sign-in" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:lichess] = OmniAuth::AuthHash.new(
      provider: "lichess",
      uid: "lichess-uid-99",
      info: OmniAuth::AuthHash::InfoHash.new(username: "lichesshero", email: "hero@lichess.org"),
      credentials: OmniAuth::AuthHash.new(token: "token", expires_at: 1.year.from_now.to_i)
    )

    visit user_lichess_omniauth_callback_path

    expect(page).to have_current_path(dashboard_path)
    expect(page).to have_text("Lichess connected as")
    expect(page).to have_text("@lichesshero")
  end

  it "shows an error when linking a Lichess account that belongs to another user" do
    other_user = create(:user)
    create(:provider_account, user: other_user, provider_user_id: "lichess-user-1")

    user = create(:user, password: password)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Log in"

    mock_lichess_auth
    visit user_lichess_omniauth_callback_path

    expect(page).to have_current_path(dashboard_path)
    expect(page).to have_text("already linked to another user")
  end

  it "renders chart canvases when progress snapshots exist" do
    user = create(:user, password: password)
    plan = create(:training_plan, :active, user: user)
    cycle = plan.weakness_cycle
    2.times do |index|
      snapshot_at = (index + 1).days.ago
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
        weakness_cycle: cycle,
        weakness_frequency: 0.5,
        snapshot_at:,
        metadata: { "kind" => "weakness", "current_occurrences" => 3 - index }
      )
      create(
        :progress_snapshot,
        user:,
        blunders_per_game: 0.9 - (index * 0.1),
        average_centipawn_loss: 38.0 - index,
        games_analyzed_count: 10,
        snapshot_at:,
        metadata: { "kind" => "performance" }
      )
    end

    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Log in"

    expect(page).to have_text("Progress charts")
    expect(page).to have_css("canvas[aria-label='Rating history chart']")
  end
end
