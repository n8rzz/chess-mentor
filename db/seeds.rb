# frozen_string_literal: true

# Production seeds run in every environment (required for real training plans).
# Development seeds add demo accounts, sample games, and a pre-built training plan.
def load_seed_files(subdirectory)
  Rails.root.glob("db/seeds/#{subdirectory}/*.rb").sort.each { |seed_file| load seed_file }
end

load_seed_files("production")
load_seed_files("development") if Rails.env.development?
