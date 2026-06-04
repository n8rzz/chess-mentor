# Development test account for local sign-in flows.
return unless Rails.env.development?

user = User.find_or_initialize_by(email: "starship@example.com")
user.assign_attributes(
  username: "starship123",
  password: "skyd!ve",
  password_confirmation: "skyd!ve",
  role: :member
)
user.skip_confirmation! if user.new_record? || !user.confirmed?
user.save!

puts "Test user: starship@example.com / skyd!ve (username: starship123)"
