# frozen_string_literal: true

RSpec.configure do |config|
  config.around do |example|
    Sidekiq.testing!(:fake) { example.run }
  end

  config.before do
    Sidekiq::Job.clear_all
  end
end
