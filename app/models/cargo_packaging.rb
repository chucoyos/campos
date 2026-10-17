class CargoPackaging < ApplicationRecord
  TRACKING_MODES = %w[individual aggregate].freeze

  has_many :cargo_items, dependent: :restrict_with_error

  normalizes :code, with: ->(code) { code.strip.downcase }
  normalizes :name, with: ->(name) { name.strip }

  validates :code, presence: true, uniqueness: true, format: { with: /\A[a-z][a-z0-9_]*\z/ }
  validates :name, presence: true
  validates :tracking_mode, inclusion: { in: TRACKING_MODES }
  validate :tracking_rules_unchanged_when_used
  validate :capabilities_match_tracking_mode

  scope :active, -> { where(active: true) }

  private

  def tracking_rules_unchanged_when_used
    return unless persisted? && cargo_items.exists?

    %w[tracking_mode weight_required qr_allowed].each do |attribute|
      errors.add(attribute, :cannot_change_after_use) if will_save_change_to_attribute?(attribute)
    end
  end

  def capabilities_match_tracking_mode
    if tracking_mode == "aggregate"
      errors.add(:weight_required, :aggregate_not_allowed) if weight_required?
      errors.add(:qr_allowed, :aggregate_not_allowed) if qr_allowed?
    elsif tracking_mode == "individual"
      errors.add(:weight_required, :individual_required) unless weight_required?
    end
  end
end
