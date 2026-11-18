class CargoDispatchEvent < ApplicationRecord
  belongs_to :cargo_dispatch_trip, inverse_of: :events
  belongs_to :cargo_dispatch_pass, optional: true
  belongs_to :user

  validates :event, presence: true
  before_update { throw :abort }
  before_destroy { throw :abort }
end
