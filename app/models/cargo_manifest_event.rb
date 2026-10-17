class CargoManifestEvent < ApplicationRecord
  EVENTS = %w[confirm reopen].freeze

  belongs_to :cargo_manifest
  belongs_to :user, optional: true

  validates :event, inclusion: { in: EVENTS }
  validates :from_status, :to_status, presence: true

  before_update { throw :abort }
end
