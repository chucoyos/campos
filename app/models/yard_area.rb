# Grupo operativo de posiciones dentro de un bloque, opcionalmente asignado a un cliente.
class YardArea < ApplicationRecord
  belongs_to :yard_block
  belongs_to :client, optional: true
  has_many :sections, class_name: "YardAreaSection", dependent: :restrict_with_error

  normalizes :code, with: ->(code) { code.strip.upcase }
  normalizes :name, with: ->(name) { name.strip }

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true

  scope :active, -> { where(active: true) }
end
