# Espacio de piso de una nave, dividido en las subdivisiones A, B y C.
# La ocupación no se guarda: se calcula con las líneas de mercancía ubicadas aquí.
class WarehouseSlot < ApplicationRecord
  SECTIONS = %w[A B C].freeze

  belongs_to :warehouse_bay
  has_many :cargo_items, dependent: :restrict_with_error

  has_secure_token :qr_token

  before_validation :build_code

  # El QR de la etiqueta identifica la ubicación; el id interno no se expone.
  def to_param = qr_token

  validates :number, numericality: { only_integer: true, in: 1..16 }
  validates :number, uniqueness: { scope: :warehouse_bay_id }
  validates :code, uniqueness: true

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { joins(:warehouse_bay).order("warehouse_bays.number", :number) }

  private

  def build_code
    self.code = format("N%d-%02d", warehouse_bay.number, number) if warehouse_bay && number
  end
end
