class Container < ApplicationRecord
  include AASM

  NUMBER_FORMAT = /\A[A-Z]{4}\d{7}\z/
  NUMBER_PATTERN = "[A-Za-z]{4}[0-9]{7}".freeze
  SIZES = [ 20, 40 ].freeze
  # Sin MBL (solo resguardo) el contenedor nace lleno o vacío y su estado no cambia.
  STANDALONE_STATUSES = %w[lleno vacio].freeze

  belongs_to :master_bl, optional: true

  enum :container_type, { standard: "standard", hq: "hq" }, validate: true

  normalizes :number, with: ->(number) { number.gsub(/[\s-]/, "").upcase }

  validates :number, presence: true, uniqueness: true, format: { with: NUMBER_FORMAT, allow_blank: true }
  validates :size, inclusion: { in: SIZES }
  validates :status, inclusion: { in: STANDALONE_STATUSES }, unless: :with_master_bl?
  validate :master_bl_presence_unchanged, on: :update

  before_validation :start_at_activo, on: :create, if: :with_master_bl?

  aasm column: :status, whiny_persistence: true do
    state :activo, initial: true
    state :lleno
    state :vacio
    state :entregado

    event :llenar do
      transitions from: :activo, to: :lleno, guard: :with_master_bl?
    end

    event :vaciar do
      transitions from: :lleno, to: :vacio, guard: :with_master_bl?
    end

    event :entregar do
      transitions from: :vacio, to: :entregado, guard: :with_master_bl?
    end
  end

  def with_master_bl?
    master_bl_id.present?
  end

  private

  def start_at_activo
    self.status = "activo"
  end

  def master_bl_presence_unchanged
    return unless master_bl_id_changed? && master_bl_id_was.present? != master_bl_id.present?

    errors.add(:master_bl_id, :unchangeable)
  end
end
