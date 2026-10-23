class Carrier < ApplicationRecord
  USER_ROLE = "transporte".freeze

  has_many :users, dependent: :nullify
  has_many :container_assignments, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
