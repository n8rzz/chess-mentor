# frozen_string_literal: true

namespace :db do
  namespace :seed do
    desc "Load production seeds only (curated puzzles; safe in all environments)"
    task production: :environment do
      Rails.root.glob("db/seeds/production/*.rb").sort.each { |seed_file| load seed_file }
    end

    desc "Load development seeds only (demo account, games, training plan)"
    task development: :environment do
      unless Rails.env.development?
        abort "db:seed:development is only available in development"
      end

      Rails.root.glob("db/seeds/development/*.rb").sort.each { |seed_file| load seed_file }
    end
  end
end
