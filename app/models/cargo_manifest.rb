class CargoManifest < ApplicationRecord
  include AASM

  belongs_to :client
  belongs_to :container, optional: true
  has_many :cargo_items, dependent: :destroy
  has_many :events, class_name: "CargoManifestEvent", dependent: :delete_all

  aasm column: :status, whiny_persistence: true do
    state :draft, initial: true
    state :confirmed

    event :confirm, before: -> { self.confirmed_at = Time.current } do
      transitions from: :draft, to: :confirmed, guard: :cargo_items_present?, after: -> { record_event("confirm", "draft", "confirmed") }
    end

    event :reopen, before: -> { self.confirmed_at = nil } do
      transitions from: :confirmed, to: :draft, after: -> { record_event("reopen", "confirmed", "draft") }
    end
  end

  validates :container_id, uniqueness: true, allow_nil: true
  validate :container_matches_client

  scope :with_items_count, -> {
    select("cargo_manifests.*, (SELECT COUNT(*) FROM cargo_items WHERE cargo_items.cargo_manifest_id = cargo_manifests.id) AS items_count")
  }
  scope :for_client, ->(client_id) { where(client_id: client_id) }

  def general_cargo? = container_id.nil?

  def confirm_by!(user) = fire_locked(:confirm!, user)

  def reopen_by!(user) = fire_locked(:reopen!, user)

  private

  def fire_locked(event, user)
    with_lock do
      @audit_user = user
      public_send(event)
    end
  end

  def cargo_items_present? = cargo_items.exists?

  def record_event(event, from, to)
    events.build(user: @audit_user, event: event, from_status: from, to_status: to, created_at: Time.current)
  end

  def container_matches_client
    return unless container

    errors.add(:container, :wrong_client) unless container.master_bl&.client_id == client_id
  end
end
