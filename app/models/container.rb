class Container < ApplicationRecord
  include AASM

  NUMBER_FORMAT = /\A[A-Z]{4}\d{7}\z/
  NUMBER_PATTERN = "[A-Za-z]{4}[0-9]{7}".freeze
  SIZES = [ 20, 40 ].freeze
  # Sin MBL (solo resguardo) el contenedor nace lleno o vacío y su estado no cambia.
  STANDALONE_STATUSES = %w[lleno vacio].freeze

  PHOTO_SECTIONS = %w[opening deconsolidation empty].freeze
  PHOTO_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  PHOTO_MAX_SIZE = 10.megabytes
  MAX_PHOTOS_PER_UPLOAD = 30

  belongs_to :master_bl, optional: true
  # Cliente propietario de un contenedor de resguardo (sin MBL).
  belongs_to :client, optional: true
  has_one :cargo_manifest, dependent: :restrict_with_error

  has_many_attached :opening_photos
  has_many_attached :deconsolidation_photos
  has_many_attached :empty_photos

  enum :container_type, { standard: "standard", hq: "hq" }, validate: true

  normalizes :number, with: ->(number) { number.gsub(/[\s-]/, "").upcase }

  validates :number, presence: true, uniqueness: true, format: { with: NUMBER_FORMAT, allow_blank: true }
  validates :size, inclusion: { in: SIZES }
  validates :status, inclusion: { in: STANDALONE_STATUSES }, unless: :with_master_bl?
  validates :client, presence: true, on: :create, unless: :with_master_bl?
  validate :master_bl_presence_unchanged, on: :update
  validate :photos_are_valid_images

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

  def owner_client_id = master_bl&.client_id || client_id

  def photos_zip_name(section)
    "#{number}_#{I18n.t("containers.photos.#{section}").parameterize}.zip"
  end

  # ZIP vigente (menos de 1 hora y sin fotos nuevas posteriores), para reconstruir el enlace al volver a la vista.
  def ready_photos_zip(section, ttl: 1.hour)
    blob = ActiveStorage::Blob.where(filename: photos_zip_name(section), content_type: "application/zip")
                              .where(created_at: ttl.ago..).order(created_at: :desc).first
    return unless blob

    newest_photo = public_send(:"#{section}_photos_attachments").maximum(:created_at)
    blob if newest_photo && newest_photo <= blob.created_at
  end

  def with_master_bl?
    master_bl_id.present?
  end

  private

  def photos_are_valid_images
    PHOTO_SECTIONS.each do |section|
      attribute = :"#{section}_photos"
      public_send(attribute).each do |photo|
        errors.add(attribute, :invalid_type, filename: photo.filename) unless PHOTO_CONTENT_TYPES.include?(photo.blob.content_type)
        errors.add(attribute, :too_large, filename: photo.filename, max: PHOTO_MAX_SIZE / 1.megabyte) if photo.blob.byte_size > PHOTO_MAX_SIZE
      end
    end
  end

  def start_at_activo
    self.status = "activo"
  end

  def master_bl_presence_unchanged
    return unless master_bl_id_changed? && master_bl_id_was.present? != master_bl_id.present?

    errors.add(:master_bl_id, :unchangeable)
  end
end
