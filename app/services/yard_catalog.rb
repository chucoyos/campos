# Deja el catálogo del patio (bloques, posiciones y áreas) exactamente como lo define DEFINITION.
# Solo escribe en yard_blocks, yard_slots y yard_areas; es repetible para el ciclo de revisión con el cliente.
class YardCatalog
  # Cada bahía es un lugar de 20 pies; un contenedor de 40 pies ocupa dos bahías contiguas.
  BLOCKS = [
    { code: "1A", bays: 36, rows: 2,  levels: 5 },
    { code: "1B", bays: 12, rows: 3,  levels: 5 },
    { code: "1C", bays: 20, rows: 7,  levels: 5 },
    { code: "1D", bays: 4,  rows: 12, levels: 5 },
    { code: "2D", bays: 4,  rows: 12, levels: 5 },
    { code: "3D", bays: 4,  rows: 12, levels: 5 }
  ].freeze

  AREAS = [
    { code: YardArea::DESYCON, name: "DesyCon", capacity: 72 }
  ].freeze

  Result = Struct.new(:blocks, :areas, keyword_init: true)

  def initialize(blocks: BLOCKS, areas: AREAS)
    @blocks = blocks
    @areas = areas
  end

  def call
    ActiveRecord::Base.transaction do
      YardBlock.where.not(code: @blocks.pluck(:code)).find_each { |block| remove(block) }
      YardArea.where.not(code: @areas.pluck(:code)).delete_all

      areas = @areas.map { |attributes| YardArea.find_or_initialize_by(code: attributes[:code]).tap { |area| area.update!(attributes) } }
      blocks = @blocks.map { |attributes| sync_block(attributes) }
      Result.new(blocks: blocks, areas: areas)
    end
  end

  private

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
