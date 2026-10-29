# Deja el catálogo del patio (bloques y posiciones) exactamente como lo define BLOCKS.
# Solo escribe en yard_blocks y yard_slots; es repetible para el ciclo de revisión con el cliente.
class YardCatalog
  # Cada bahía es un lugar de 20 pies; un contenedor de 40 pies ocupa dos bahías contiguas.
  BLOCKS = [
    { code: "1A", bays: 36, rows: 2,  levels: 5 },
    { code: "1B", bays: 12, rows: 3,  levels: 5 },
    { code: "1C", bays: 20, rows: 7,  levels: 5 },
    { code: "1CFS", bays: 4, rows: 12, levels: 1 },
    { code: "2CFS", bays: 4, rows: 12, levels: 1 },
    { code: "3CFS", bays: 4, rows: 12, levels: 1 }
  ].freeze

  # Los bloques CFS forman el área DESYCON, destino de la desconsolidación.
  DESYCON_BLOCKS = %w[1CFS 2CFS 3CFS].freeze

  # Bloques que cambiaron de código: se renombran en su lugar para conservar sus posiciones y su estado.
  RENAMES = { "1D" => "1CFS", "2D" => "2CFS", "3D" => "3CFS" }.freeze

  Result = Struct.new(:blocks, keyword_init: true)

  def initialize(blocks: BLOCKS, renames: RENAMES)
    @blocks = blocks
    @renames = renames
  end

  def call
    ActiveRecord::Base.transaction do
      apply_renames
      YardBlock.where.not(code: @blocks.pluck(:code)).find_each { |block| remove(block) }

      Result.new(blocks: @blocks.map { |attributes| sync_block(attributes) })
    end
  end

  private

  def apply_renames
    @renames.each do |old_code, new_code|
      block = YardBlock.find_by(code: old_code)
      next unless block && @blocks.any? { |attributes| attributes[:code] == new_code } && !YardBlock.exists?(code: new_code)

      block.update!(code: new_code)
      YardSlot.where(yard_block_id: block.id).update_all([ "code = ? || bay || row || level", new_code ])
    end
  end

  def sync_block(attributes)
    block = YardBlock.find_or_initialize_by(code: attributes[:code])
    block.update!(attributes)
    sync_slots(block)
    block
  end

  # Las posiciones existentes conservan su estado (enabled); solo se crean las faltantes y se quitan las sobrantes.
  def sync_slots(block)
    wanted = positions(block)
    existing = block.yard_slots.pluck(:bay, :row, :level)

    YardSlot.where(yard_block_id: block.id).where.not(id: YardSlot.where(yard_block_id: block.id).where(bay: 1..block.bays, row: block.row_letters, level: 1..block.levels)).delete_all

    missing = wanted - existing
    return if missing.empty?

    now = Time.current
    YardSlot.insert_all(missing.map { |bay, row, level|
      { yard_block_id: block.id, bay: bay, row: row, level: level, code: "#{block.code}#{bay}#{row}#{level}", created_at: now, updated_at: now }
    })
  end

  def positions(block)
    (1..block.bays).to_a.product(block.row_letters, (1..block.levels).to_a)
  end

  def remove(block)
    YardSlot.where(yard_block_id: block.id).delete_all
    block.destroy!
  end
end
