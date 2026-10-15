class YardBlock < ApplicationRecord
  CODE_FORMAT = /\A\d[A-Z]+\z/

  has_many :yard_slots, dependent: :restrict_with_error

  normalizes :code, with: ->(code) { code.strip.upcase }

  validates :code, presence: true, uniqueness: true, format: { with: CODE_FORMAT, allow_blank: true }
  validates :bays, :levels, numericality: { only_integer: true, greater_than: 0 }
  validates :rows, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 26 }

  scope :enabled, -> { where(enabled: true) }

  # Letras de fila (carril) del bloque: A, B, C...
  def row_letters
    ("A"..).first(rows.to_i)
  end

  # Cada bahía es un lugar de 20 pies.
  def slots_count
    bays * rows * levels
  end
end
