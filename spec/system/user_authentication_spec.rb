require "rails_helper"

RSpec.describe "User authentication", type: :system do
  it "signs up, confirms email, signs in, and signs out" do
    visit root_path
    click_link "Sign up"

    fill_in "Username", with: "newplayer"
    fill_in "Email", with: "newplayer@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"
    click_button "Sign up"

    expect(page).to have_text("confirmation link")

    visit confirmation_path_for("newplayer@example.com")

    expect(page).to have_text("confirmed")

    sign_in_unless_signed_in(
      email: "newplayer@example.com",
      password: "password123"
    )

    expect(page).to have_text("Signed in as")
    expect(page).to have_text("newplayer")

    click_button "Sign out"

    expect(page).to have_link("Sign in")
  end

  it "signs in an existing confirmed user" do
    create(:user, username: "existing", email: "existing@example.com", password: "password123")

    visit new_user_session_path
    fill_in "Email", with: "existing@example.com"
    fill_in "Password", with: "password123"
    click_button "Log in"

    expect(page).to have_text("Signed in as")
    expect(page).to have_text("existing")
  end

  private

  def confirmation_path_for(address)
    email = ActionMailer::Base.deliveries.reverse.find { |message| message.to.include?(address) }
    raise "No email delivered to #{address}" unless email

    body = email.html_part&.body&.decoded || email.body.decoded
    uri = URI.parse(Capybara.string(body).find_link("Confirm my account")[:href])
    uri.request_uri
  end

  def sign_in_unless_signed_in(email:, password:)
    return if page.has_text?("Signed in as", wait: 0)

    visit new_user_session_path
    fill_in "Email", with: email
    fill_in "Password", with: password
    click_button "Log in"
  end
end
