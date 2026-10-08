# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Initial admin (only admins can create users). Set ADMIN_EMAIL / ADMIN_PASSWORD to override.
User.find_or_create_by!(email: ENV.fetch("ADMIN_EMAIL", "admin@mail.com")) do |user|
  user.password = ENV.fetch("ADMIN_PASSWORD", "admin123")
  user.role = "admin"
end
