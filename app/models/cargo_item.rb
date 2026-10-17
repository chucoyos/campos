class CargoItem < ApplicationRecord
  DESCRIPTION_SUGGESTIONS = [ "Acero", "Lingote de Acero" ].freeze
  DEFAULT_DESCRIPTION = DESCRIPTION_SUGGESTIONS.first

  belongs_to :cargo_manifest
  belongs_to :cargo_packaging

  attr_accessor :generate_qr

  normalizes :description, with: ->(description) { description.strip }
  normalizes :origin_identifier, with: ->(identifier) { identifier.strip.presence }

  before_validation :assign_qr_token, if: -> { generate_qr? && cargo_packaging&.qr_allowed? }

  validates :description, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :weight_kg, numericality: { greater_than: 0 }, allow_nil: true
  validates :qr_token, uniqueness: true, allow_nil: true
  validate :manifest_is_draft
  validate :packaging_is_active, if: :new_record_or_packaging_changed?
  validate :packaging_rules
  validate :qr_available_for_packaging

  def individual? = cargo_packaging&.tracking_mode == "individual"

  def generate_qr? = ActiveModel::Type::Boolean.new.cast(generate_qr)

  private

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
