class CargoManifest < ApplicationRecord
  belongs_to :client
  belongs_to :container, optional: true
  has_many :cargo_items, dependent: :destroy

  validates :status, inclusion: { in: %w[draft confirmed] }
  validates :container_id, uniqueness: true, allow_nil: true
  validate :container_matches_client

  scope :with_items_count, -> {
    select("cargo_manifests.*, (SELECT COUNT(*) FROM cargo_items WHERE cargo_items.cargo_manifest_id = cargo_manifests.id) AS items_count")
  }
  scope :for_client, ->(client_id) { where(client_id: client_id) }

  def draft? = status == "draft"
  def confirmed? = status == "confirmed"
  def general_cargo? = container_id.nil?

  def confirm!
    with_lock do
      unless draft? && cargo_items.exists?
        errors.add(:base, :cannot_confirm)
        raise ActiveRecord::RecordInvalid, self
      end

      update!(status: "confirmed", confirmed_at: Time.current)
    end
  end

  def reopen!
    with_lock do
      raise ActiveRecord::RecordInvalid, self unless confirmed?

      update!(status: "draft", confirmed_at: nil)
    end
  end

  private

  def container_matches_client
    return unless container

    errors.add(:container, :wrong_client) unless container.master_bl&.client_id == client_id
  end
end
