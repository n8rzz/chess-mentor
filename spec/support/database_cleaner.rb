RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before do |example|
    if example.metadata[:skip_database_cleaner]
      DatabaseCleaner.strategy = :truncation
      DatabaseCleaner.clean
    else
      DatabaseCleaner.strategy =
        if example.metadata[:type] == :system || example.metadata[:db_cleaner] == :truncation
          :truncation
        else
          :transaction
        end
    end
  end

  config.after do |example|
    next unless example.metadata[:skip_database_cleaner]

    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean
  end

  config.around do |example|
    if example.metadata[:skip_database_cleaner]
      example.run
    else
      DatabaseCleaner.cleaning do
        example.run
      end
    end
  end
end
