# Deja el catálogo de la bodega exactamente como lo define BAYS. Es repetible: solo crea lo que falta.
class WarehouseCatalog
  SLOTS_PER_BAY = (1..16).to_a.freeze

  # Ubicaciones que no existen físicamente por nave.
  MISSING_SLOTS = { 1 => [ 8 ] }.freeze

  # Espacio libre del plano: nave => ubicación tras la cual queda. Solo afecta al mapa.
  FREE_SPACE_AFTER = { 1 => 4 }.freeze

  def self.slot_numbers(bay_number)
    SLOTS_PER_BAY - MISSING_SLOTS.fetch(bay_number, [])
  end

  def call
    ActiveRecord::Base.transaction do
      (1..4).map do |number|
        bay = WarehouseBay.find_or_create_by!(number: number)
        self.class.slot_numbers(number).each { |slot| bay.warehouse_slots.find_or_create_by!(number: slot) }
        bay
      end
    end
  end
end
