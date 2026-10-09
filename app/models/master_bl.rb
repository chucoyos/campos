class MasterBl < ApplicationRecord
  belongs_to :client
  has_many :containers, dependent: :restrict_with_error

  normalizes :number, with: ->(number) { number.strip.upcase }

  validates :number, presence: true, uniqueness: true
end
