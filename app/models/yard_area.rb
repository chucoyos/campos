class YardArea < ApplicationRecord
  DESYCON = "DESYCON".freeze

  normalizes :code, with: ->(code) { code.strip.upcase }

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :enabled, -> { where(enabled: true) }
end
