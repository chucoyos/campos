class Client < ApplicationRecord
  belongs_to :user, optional: true

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
