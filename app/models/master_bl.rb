class MasterBl < ApplicationRecord
  belongs_to :client

  normalizes :number, with: ->(number) { number.strip.upcase }

  validates :number, presence: true, uniqueness: true
end
