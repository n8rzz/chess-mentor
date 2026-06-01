## New Command

rails new $PROJECT_NAME \
 -d postgresql \
 -c tailwind \
 -T \
 --skip-system-test \
 --skip-jbuilder \
 --skip-solid \
 --skip-thruster \
 --skip-brakeman \
 --skip-devcontainer

## Initial Setup

- [ ] docker-compose
  - [ ] create `.env`
  - [ ] dotenv-rails
  - [ ] update `database.yml` to use env vars for docker
- [ ] testing
  - [ ] rspec
  - [ ] factory bot
  - [ ] capybara
  - [ ] shoulda-matchers
  - [ ] database cleaner
  - [ ] selenium-webdriver
- [ ] ULID id generators
- [ ] `annotaterb` gem
- [ ] devise email+password (username, email, password, role, confirmable)
  - [ ] generate devise views
  - [ ] letteropener
  - [ ] dev + test mailer
  - [ ] user model test
  - [ ] basic user flow system specs
  - [ ] test user seeds
- [ ] redis
  - [ ] update docker-compose
  - [ ] sidekiq
