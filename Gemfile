source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 2.0"
gem "ulid", "~> 1.4"
gem "redis", "~> 5.4"
gem "sidekiq", "~> 8.1"
gem "devise", "~> 5.0"
gem "omniauth", "~> 2.1"
gem "omniauth-rails_csrf_protection"
gem "omniauth-oauth2", "~> 1.9"
# Transitive pins for bundler-audit (CVE advisories on main CI)
gem "net-imap", ">= 0.6.4.1"
gem "concurrent-ruby", ">= 1.3.7"
gem "crass", ">= 1.0.7"
gem "faraday", ">= 2.14.3"
gem "loofah", ">= 2.25.2"
gem "mail", ">= 2.9.1"
gem "msgpack", ">= 1.8.2"
gem "nokogiri", ">= 1.19.4"
gem "rails-html-sanitizer", ">= 1.7.1"
gem "rubyzip", ">= 3.4.0"
gem "websocket-driver", ">= 0.8.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  gem "dotenv-rails", "~> 3.2"
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails", "~> 6.5"
end

group :test do
  gem "capybara", "~> 3.40"
  gem "shoulda-matchers", "~> 7.0"
  gem "database_cleaner-active_record", "~> 2.2"
  gem "selenium-webdriver", "~> 4.44"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
  gem "annotaterb", "~> 4.24"
  gem "letter_opener", "~> 1.10"
end
