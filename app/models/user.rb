class User < ApplicationRecord
  ROLES = %w[admin cliente transporte seguridad grua montacargas].freeze

  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  enum :role, ROLES.index_with(&:itself), validate: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :role, presence: true
end
