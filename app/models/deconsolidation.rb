# Proceso de vaciado de un contenedor en DESYCON: apertura, desconsolidación y vacío.
class Deconsolidation < ApplicationRecord
  include AASM

  # Cada etapa activa corresponde a la sección de fotos del contenedor que debe documentarla.
  STAGE_PHOTO_SECTIONS = {
    "apertura" => "opening",
    "desconsolidando" => "deconsolidation",
    "vacio" => "empty"
  }.freeze

  belongs_to :container
  belongs_to :created_by, class_name: "User", optional: true

  validates :container_id, uniqueness: true

  after_commit -> { Turbo::StreamsChannel.broadcast_refresh_to(WorkOrder::STREAM) }

  scope :in_progress, -> { where.not(status: "vaciado") }

  aasm column: :status do
    state :apertura, initial: true
    state :desconsolidando
    state :vacio
    state :vaciado

    event :iniciar_desconsolidacion do
      transitions from: :apertura, to: :desconsolidando, guard: :opening_photos_present?, after: -> { self.started_at = Time.current }
    end

    event :registrar_vacio do
      transitions from: :desconsolidando, to: :vacio, guard: %i[deconsolidation_photos_present? cargo_fully_stored?]
    end

    event :vaciar do
      transitions from: :vacio, to: :vaciado, guard: :empty_photos_present?, after: -> { self.emptied_at = Time.current }
    end
  end

  def cargo_items
    container.cargo_manifest ? container.cargo_manifest.cargo_items : CargoItem.none
  end

  def pending_cargo_items = cargo_items.where.not(status: "stored")

  def stored_count = cargo_items.where(status: "stored").count

  def total_count = cargo_items.count

  def photo_count(section) = container.public_send(:"#{section}_photos").count

  def opening_photos_present? = photo_count("opening").positive?
  def deconsolidation_photos_present? = photo_count("deconsolidation").positive?
  def empty_photos_present? = photo_count("empty").positive?
  def cargo_fully_stored? = pending_cargo_items.none?
end
