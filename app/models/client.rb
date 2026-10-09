class Client < ApplicationRecord
  belongs_to :user, optional: true
  has_many :master_bls, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
