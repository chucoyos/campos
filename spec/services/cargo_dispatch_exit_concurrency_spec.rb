require "rails_helper"
require "timeout"

RSpec.describe "Salidas simultáneas de despacho" do
  self.use_transactional_tests = false

  it "counts each confirmed allocation once when two trips and repeated scans exit concurrently" do
    client = admin = packaging = manifest = item = request_record = nil
    passes = []
    threads = []

    begin
      ActiveRecord::Base.transaction do
        suffix = SecureRandom.hex(12)
        client = create(:client, name: "Prueba concurrencia #{suffix}")
        admin = create(:user, :admin, email: "dispatch-#{suffix}@example.test")
        packaging = create(:cargo_packaging, :box, code: "box_#{suffix}")
        manifest = create(:cargo_manifest, client: client)
        item = create(:cargo_item, cargo_manifest: manifest, cargo_packaging: packaging,
          quantity: 10, weight_kg: nil, status: "dispatched")
        manifest.confirm_by!(admin)
        request_record = CargoDispatchRequest.create!(client: client, requested_by: admin, destination: "Destino")
        instruction = request_record.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 10)

        [ 4, 6 ].each do |quantity|
          trip = request_record.trips.create!(origin_type: "general", transport_mode: "customer",
            transport_name: "Propio", created_by: admin, status: "loaded")
          trip.allocations.create!(cargo_dispatch_instruction: instruction, cargo_item: item,
            reserved_quantity: quantity, reported_quantity: quantity, loaded_quantity: quantity,
            status: "confirmed", confirmed_by: admin, confirmed_at: Time.current)
          passes << trip.passes.create!(requested_by: admin, operator_name: "Operador", plate: "ABC123",
            unit_type: "sencillo", entered_at: Time.current, exit_scanned_at: Time.current)
        end
      end

      ready = Queue.new
      start = Queue.new
      threads = (passes * 2).map do |pass|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()")
            start.pop
            CargoDispatchOperationService.exit!(pass: pass, user: admin)
          end
        end
      end
      backend_ids = Timeout.timeout(10) do
        ids = 4.times.map { ready.pop }
        4.times { start << true }
        threads.each(&:value)
        ids
      end

      expect(backend_ids.uniq.size).to eq(4)
      expect(CargoDispatchAllocation.delivered.where(cargo_item: item).sum(:loaded_quantity)).to eq(10)
      expect(CargoDispatchEvent.where(cargo_dispatch_trip_id: passes.map(&:cargo_dispatch_trip_id), event: "exited").count).to eq(2)
      expect(passes.map { |pass| pass.reload.completed_at }).to all(be_present)
    ensure
      threads.each(&:kill)
      threads.each(&:join)
      ActiveRecord::Base.transaction do
        trip_ids = CargoDispatchTrip.where(cargo_dispatch_request_id: request_record.id).select(:id) if request_record&.persisted?
        if trip_ids
          CargoDispatchEvent.where(cargo_dispatch_trip_id: trip_ids).delete_all
          CargoDispatchPass.where(cargo_dispatch_trip_id: trip_ids).delete_all
          CargoDispatchAllocation.where(cargo_dispatch_trip_id: trip_ids).delete_all
          CargoDispatchTrip.where(id: trip_ids).delete_all
          CargoDispatchInstruction.where(cargo_dispatch_request_id: request_record.id).delete_all
          CargoDispatchRequest.where(id: request_record.id).delete_all
        end
        CargoManifestEvent.where(cargo_manifest_id: manifest.id).delete_all if manifest&.persisted?
        CargoItem.where(id: item.id).delete_all if item&.persisted?
        CargoManifest.where(id: manifest.id).delete_all if manifest&.persisted?
        CargoPackaging.where(id: packaging.id).delete_all if packaging&.persisted?
        User.where(id: admin.id).delete_all if admin&.persisted?
        Client.where(id: client.id).delete_all if client&.persisted?
      end
    end
  end
end
