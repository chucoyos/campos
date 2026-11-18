class MasterBl < ApplicationRecord
  belongs_to :client
  has_many :containers, dependent: :restrict_with_error
  has_one_attached :document

  DOCUMENT_CONTENT_TYPES = %w[application/pdf].freeze
  DOCUMENT_MAX_SIZE = 10.megabytes

  normalizes :number, with: ->(number) { number.strip.upcase }

  validates :number, presence: true, uniqueness: true
  validate :document_is_valid_pdf

  scope :with_dispatch_inventory, -> {
    inventory_join = <<~SQL.squish
      LEFT JOIN (
        SELECT containers.master_bl_id,
               SUM(cargo_items.quantity) AS captured_units,
               SUM(cargo_items.quantity - COALESCE(dispatch_totals.loaded, 0)) AS physical_units,
               SUM(COALESCE(dispatch_totals.reserved, 0)) AS reserved_units,
               SUM(CASE WHEN cargo_manifests.status = 'confirmed' AND cargo_items.status = 'stored'
                   THEN cargo_items.quantity - COALESCE(dispatch_totals.loaded, 0) - COALESCE(dispatch_totals.reserved, 0)
                   ELSE 0 END) AS available_units
        FROM containers
        INNER JOIN cargo_manifests ON cargo_manifests.container_id = containers.id
        INNER JOIN cargo_items ON cargo_items.cargo_manifest_id = cargo_manifests.id
        LEFT JOIN (
          SELECT cargo_item_id,
                 SUM(CASE WHEN status = 'confirmed' THEN loaded_quantity ELSE 0 END) AS loaded,
                 SUM(CASE WHEN status = 'reserved' THEN reserved_quantity ELSE 0 END) AS reserved
          FROM cargo_dispatch_allocations GROUP BY cargo_item_id
        ) dispatch_totals ON dispatch_totals.cargo_item_id = cargo_items.id
        GROUP BY containers.master_bl_id
      ) dispatch_inventory ON dispatch_inventory.master_bl_id = master_bls.id
    SQL
    joins(inventory_join).select(
      "master_bls.*, COALESCE(dispatch_inventory.captured_units, 0) AS captured_units, " \
      "COALESCE(dispatch_inventory.physical_units, 0)::bigint AS physical_units, " \
      "COALESCE(dispatch_inventory.reserved_units, 0)::bigint AS reserved_units, " \
      "COALESCE(dispatch_inventory.available_units, 0)::bigint AS available_units"
    )
  }

  # El cliente solo puede modificar su MBL mientras ningún contenedor haya avanzado de "activo".
  def open_for_client?
    !containers.where.not(status: "activo").exists?
  end

  private

  def document_is_valid_pdf
    return unless document.attached?

    errors.add(:document, :invalid_type) unless DOCUMENT_CONTENT_TYPES.include?(document.blob.content_type)
    errors.add(:document, :too_large, max: DOCUMENT_MAX_SIZE / 1.megabyte) if document.blob.byte_size > DOCUMENT_MAX_SIZE
  end
end
