# Camión y operador que participan en un pase; el traspaleo lleva un segundo vehículo (destino).
class MovementPassVehicle < ApplicationRecord
  ROLES = %w[principal destino].freeze
  UNIT_TYPES = %w[sencillo full].freeze

  belongs_to :movement_pass
  belongs_to :carrier

  enum :unit_type, UNIT_TYPES.index_with(&:itself), validate: true

  normalizes :operator_name, with: ->(value) { value.strip }
  normalizes :economic_number, with: ->(value) { value.strip.upcase }
  normalizes :plate, with: ->(plate) { plate.gsub(/[\s-]/, "").upcase }

  validates :role, inclusion: { in: ROLES }, uniqueness: { scope: :movement_pass_id }
  validates :operator_name, :plate, presence: true

  delegate :name, to: :carrier, prefix: true
end
