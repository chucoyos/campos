# Catálogo del patio. Se ejecuta con: bin/rails db:seed:yard
# Solo escribe en yard_blocks, yard_slots y yard_areas; es repetible y no toca otras tablas.
result = YardCatalog.new.call

result.blocks.each do |block|
  puts "Bloque #{block.code}: #{block.bays} bahías x #{block.rows} filas x #{block.levels} niveles = #{block.slots_count} lugares de 20 pies"
end
result.areas.each { |area| puts "Área #{area.code}: capacidad #{area.capacity || 'desconocida'}" }
puts "Total de posiciones: #{YardSlot.count}"
