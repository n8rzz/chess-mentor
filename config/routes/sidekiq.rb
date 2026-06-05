require "sidekiq/web"

# Sidekiq Web needs a session for CSRF protection.
Sidekiq::Web.use ActionDispatch::Cookies
Sidekiq::Web.use ActionDispatch::Session::CookieStore, key: "_chess_mentor_session"

authenticate :user, ->(user) { user.admin? } do
  mount Sidekiq::Web => "/jobs"
end
