# Load seed files from db/seeds/ in lexical order (e.g. 01_users.rb, 02_puzzles.rb).
Rails.root.glob("db/seeds/*.rb").sort.each { |seed_file| load seed_file }
