require "rails_helper"

RSpec.describe "Health check", type: :system do
  it "loads the health endpoint" do
    visit "/up"

    expect(page).to have_current_path("/up")
    expect(page).not_to have_text("Exception")
  end
end
