class Carrier < ApplicationRecord
  USER_ROLE = "transporte".freeze

  has_many :users, dependent: :nullify

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
