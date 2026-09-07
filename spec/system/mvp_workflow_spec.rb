# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MVP workflow", type: :system, skip_database_cleaner: true do
  let(:password) { "password123" }

  before { skip_unless_pipeline_ready! }

  it "covers register through assignment completion" do
    visit new_user_registration_path
    fill_in "Username", with: "mvpplayer"
    fill_in "Email", with: "mvpplayer@example.com"
    fill_in "Password", with: password
    fill_in "Password confirmation", with: password
    click_button "Sign up"

    expect(page).to have_current_path(dashboard_path)
    expect(page).to have_text("mvpplayer")

    mock_lichess_auth(uid: "mvp-lichess-uid", username: "mvpplayer")
    visit user_lichess_omniauth_callback_path
    expect(page).to have_text("Lichess connected as")

    visit new_import_batch_path
    click_button "Start import"

    expect(page).to have_current_path(%r{/import_batches/})
    batch = ImportBatch.last

    workflow_driver.drain_pending_jobs!
    AnalysisRuns::ReconcileAll.call
    workflow_driver.drain_pending_jobs!

    visit import_batch_path(batch)
    expect(page).to have_text("succeeded")

    visit pattern_cycles_path
    expect(page).to have_text("Recurring patterns")

    user = User.find_by!(email: "mvpplayer@example.com")
    cycle = user.pattern_cycles.first
    expect(cycle).to be_present
    create_list(:puzzle, 5, pattern: cycle.pattern) if Puzzle.where(pattern: cycle.pattern).count < 5

    visit training_plans_path
    click_button "Start plan"

    plan = user.training_plans.active.first
    expect(plan).to be_present
    workflow_driver.wait_for_training_plan_assignments!(plan)

    visit today_training_plan_path(plan)
    expect(page).to have_text("Today's assignments")

    first(:button, "Complete").click
    expect(page).to have_text("Assignment marked complete")
  end
end
