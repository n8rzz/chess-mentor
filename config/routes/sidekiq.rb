require "sidekiq/web"

# Sidekiq Web needs a session for CSRF protection.
Sidekiq::Web.use ActionDispatch::Cookies
Sidekiq::Web.use ActionDispatch::Session::CookieStore, key: "_chess_mentor_session"

# Open for now; restrict with Devise once authentication is in place.
mount Sidekiq::Web => "/jobs"
