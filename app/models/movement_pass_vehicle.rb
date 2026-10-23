# Camión y operador que participan en un pase; el traspaleo lleva un segundo vehículo (destino).
class MovementPassVehicle < ApplicationRecord
  ROLES = %w[principal destino].freeze
  UNIT_TYPES = %w[sencillo full].freeze

  belongs_to :movement_pass

  enum :unit_type, UNIT_TYPES.index_with(&:itself), validate: true

  normalizes :company_name, :operator_name, with: ->(value) { value.strip }
  normalizes :plate, with: ->(plate) { plate.gsub(/[\s-]/, "").upcase }

  validates :role, inclusion: { in: ROLES }, uniqueness: { scope: :movement_pass_id }
  validates :company_name, :operator_name, :plate, presence: true
end
