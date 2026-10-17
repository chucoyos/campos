# Catálogo de la bodega. Se ejecuta con: bin/rails db:seed:warehouse
# Solo escribe en warehouse_bays y warehouse_slots; es repetible.
WarehouseCatalog.new.call

WarehouseBay.ordered.each do |bay|
  puts "Nave #{bay.number}: #{bay.warehouse_slots.count} ubicaciones"
end
puts "Total de ubicaciones: #{WarehouseSlot.count}"
