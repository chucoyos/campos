class WarehouseBay < ApplicationRecord
  has_many :warehouse_slots, dependent: :restrict_with_error

  validates :number, numericality: { only_integer: true, in: 1..4 }, uniqueness: true

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:number) }
end
