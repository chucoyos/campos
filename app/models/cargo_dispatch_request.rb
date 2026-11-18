class CargoDispatchRequest < ApplicationRecord
  include AASM

  belongs_to :client
  belongs_to :requested_by, class_name: "User"
  has_many :instructions, class_name: "CargoDispatchInstruction", dependent: :restrict_with_error, inverse_of: :cargo_dispatch_request
  has_many :trips, class_name: "CargoDispatchTrip", dependent: :restrict_with_error, inverse_of: :cargo_dispatch_request
  accepts_nested_attributes_for :instructions

  normalizes :destination, with: ->(value) { value.strip }
  validates :destination, presence: true

  aasm column: :status, whiny_persistence: true do
    state :pending, initial: true
    state :in_progress
    state :completed
    state :cancelled

    event :start do
      transitions from: :pending, to: :in_progress
    end
  end
end
