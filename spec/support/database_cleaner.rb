RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around do |example|
    if example.metadata[:skip_database_cleaner]
      DatabaseCleaner.strategy = :truncation
      DatabaseCleaner.clean
      example.run
      DatabaseCleaner.clean
      next
    end

    # Strategy must be set before DatabaseCleaner.cleaning starts. Setting it in a
    # before hook is too late — around already chose the previous example's strategy.
    DatabaseCleaner.strategy =
      if example.metadata[:type] == :system || example.metadata[:db_cleaner] == :truncation
        :truncation
      else
        :transaction
      end

    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
