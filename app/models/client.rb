class Client < ApplicationRecord
  USER_ROLE = "cliente".freeze

  has_many :users, dependent: :nullify
  has_many :master_bls, dependent: :restrict_with_error
  has_many :cargo_manifests, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
