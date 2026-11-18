class CargoDispatchAllocation < ApplicationRecord
  include AASM
  belongs_to :cargo_dispatch_trip, inverse_of: :allocations
  belongs_to :cargo_dispatch_instruction
  belongs_to :cargo_item
  belongs_to :warehouse_slot, optional: true
  belongs_to :confirmed_by, class_name: "User", optional: true
  belongs_to :reported_by, class_name: "User", optional: true

  validates :reserved_quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :reported_quantity, :loaded_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  aasm column: :status, whiny_persistence: true do
    state :reserved, initial: true
    state :confirmed
    state :released

    event :confirm_loading do
      transitions from: :reserved, to: :confirmed
    end
    event :release do
      transitions from: :reserved, to: :released
    end
  end

  before_update { throw :abort if status_in_database.in?(%w[confirmed released]) }
  before_destroy { throw :abort }
end
