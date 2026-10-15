# Catálogo del patio. Se ejecuta con: bin/rails db:seed:yard
# Solo escribe en yard_blocks y yard_slots; es repetible y no toca otras tablas.
result = YardCatalog.new.call

result.blocks.each do |block|
  puts "Bloque #{block.code}: #{block.bays} bahías x #{block.rows} filas x #{block.levels} niveles = #{block.slots_count} lugares de 20 pies"
end
puts "Total de posiciones: #{YardSlot.count}"
