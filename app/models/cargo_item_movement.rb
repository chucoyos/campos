class CargoItemMovement < ApplicationRecord
  belongs_to :cargo_item
  belongs_to :from_slot, class_name: "WarehouseSlot", optional: true
  belongs_to :to_slot, class_name: "WarehouseSlot"
  belongs_to :user, optional: true

  validates :to_section, inclusion: { in: WarehouseSlot::SECTIONS }

  before_update { throw :abort }
end
