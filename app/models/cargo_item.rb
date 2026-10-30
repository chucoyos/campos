class CargoItem < ApplicationRecord
  include AASM

  LOCATION_ATTRIBUTES = %w[warehouse_slot_id slot_section status updated_at].freeze

  DESCRIPTION_SUGGESTIONS = [ "Acero", "Lingote de Acero" ].freeze
  DEFAULT_DESCRIPTION = DESCRIPTION_SUGGESTIONS.first

  belongs_to :cargo_manifest
  belongs_to :cargo_packaging
  belongs_to :warehouse_slot, optional: true
  has_many :movements, class_name: "CargoItemMovement", dependent: :delete_all

  aasm column: :status, whiny_persistence: true do
    state :captured, initial: true
    state :stored

    event :store do
      transitions from: %i[captured stored], to: :stored, guard: :manifest_confirmed?, after: :record_movement
    end
  end

  attr_accessor :generate_qr

  normalizes :description, with: ->(description) { description.strip }
  normalizes :origin_identifier, with: ->(identifier) { identifier.strip.presence }

  before_validation :assign_qr_token, if: -> { generate_qr? && cargo_packaging&.qr_allowed? }

  validates :description, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :weight_kg, numericality: { greater_than: 0 }, allow_nil: true
  validates :qr_token, uniqueness: true, allow_nil: true
  validate :manifest_is_draft, unless: :location_change_only?
  validate :location_valid
  validate :packaging_is_active, if: :new_record_or_packaging_changed?
  validate :packaging_rules
  validate :qr_available_for_packaging

  def individual? = cargo_packaging&.tracking_mode == "individual"

  # Ubica o reubica la línea; el historial queda con el usuario y la fecha.
  def store_at!(slot, section, user)
    with_lock do
      @previous_location = [ warehouse_slot, slot_section ]
      @audit_user = user
      assign_attributes(warehouse_slot: slot, slot_section: section)
      store!
    end
  rescue StandardError
    restore_attributes
    raise
  end

  # Identificador legible para distinguir bultos iguales en consola y etiquetas.
  def identifier_label
    [ "##{id}", origin_identifier ].compact.join(" · ")
  end

  def location_label
    "#{warehouse_slot.code} · #{slot_section}" if warehouse_slot
  end

  def generate_qr? = ActiveModel::Type::Boolean.new.cast(generate_qr)

  private

  def manifest_confirmed? = cargo_manifest&.confirmed?

  def record_movement
    movements.build(user: @audit_user, from_slot: @previous_location&.first, from_section: @previous_location&.last,
                    to_slot: warehouse_slot, to_section: slot_section, created_at: Time.current)
  end

  def location_change_only?
    persisted? && manifest_confirmed? && (changed - LOCATION_ATTRIBUTES).empty?
  end

  def location_valid
    return unless will_save_change_to_warehouse_slot_id? || will_save_change_to_slot_section?

    errors.add(:cargo_manifest, :not_confirmed) unless manifest_confirmed?
    return unless warehouse_slot

    errors.add(:warehouse_slot, :disabled) unless warehouse_slot.enabled?
    errors.add(:slot_section, :inclusion) unless WarehouseSlot::SECTIONS.include?(slot_section)
  end

  def assign_qr_token
    self.qr_token ||= SecureRandom.urlsafe_base64(24)
  end

  def manifest_is_draft
    errors.add(:cargo_manifest, :not_draft) unless cargo_manifest&.draft?
  end

  def packaging_is_active
    errors.add(:cargo_packaging, :inactive) if cargo_packaging && !cargo_packaging.active?
  end

  def new_record_or_packaging_changed?
    new_record? || will_save_change_to_cargo_packaging_id?
  end

  def packaging_rules
    return unless cargo_packaging

    if individual?
      errors.add(:quantity, :individual_quantity) unless quantity == 1
      errors.add(:weight_kg, :blank) if cargo_packaging.weight_required? && weight_kg.blank?
    else
      errors.add(:weight_kg, :not_allowed) if weight_kg.present?
    end

    errors.add(:qr_token, :not_allowed) if qr_token.present? && !(individual? && cargo_packaging.qr_allowed?)
  end

  def qr_available_for_packaging
    return unless generate_qr?
    return if cargo_packaging&.qr_allowed?

    errors.add(:generate_qr, :not_allowed)
  end
end
