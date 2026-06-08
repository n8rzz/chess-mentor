require "sidekiq/web"

# Sidekiq Web needs a session for CSRF protection.
Sidekiq::Web.use ActionDispatch::Cookies
Sidekiq::Web.use ActionDispatch::Session::CookieStore, key: "_chess_mentor_session"

sidekiq_auth = if Rails.env.development?
  ->(user) { user.present? }
else
  ->(user) { user.admin? }
end

authenticate :user, sidekiq_auth do
  mount Sidekiq::Web => "/jobs"
end
