require "rails_helper"

RSpec.describe "Despacho de mercancía", type: :request do
  let(:client) { create(:client) }
  let(:client_user) { create(:user, :cliente, client: client) }
  let(:admin) { create(:user, :admin) }
  let(:security) { create(:user, :seguridad) }
  let(:operator) { create(:user, :montacargas) }
  let(:packaging) { create(:cargo_packaging, :box) }
  let(:item) do
    manifest = create(:cargo_manifest, client: client)
    line = create(:cargo_item, cargo_manifest: manifest, cargo_packaging: packaging, quantity: 10, weight_kg: nil)
    manifest.confirm_by!(admin)
    line.store_at!(create(:warehouse_slot), "A", admin)
    line
  end

  it "stores several preferred containers alongside one total quantity target" do
    sign_in admin
    containers = 2.times.map do
      master_bl = create(:master_bl, client: client)
      create(:container, :with_master_bl, master_bl: master_bl)
    end

    post cargo_dispatch_requests_path, params: {
      cargo_dispatch_request: { client_id: client.id, destination: "Destino" },
      instruction: {
        criterion: "quantity", cargo_packaging_id: packaging.id, quantity: 75,
        preferred_container_ids: containers.map(&:id)
      }
    }

    request_record = CargoDispatchRequest.order(:id).last
    expect(response).to redirect_to(cargo_dispatch_request_path(request_record))
    instruction = request_record.instructions.sole
    expect(instruction).to have_attributes(criterion: "quantity", quantity: 75, cargo_packaging: packaging)
    expect(instruction.preferred_containers).to match_array(containers)

    get cargo_dispatch_request_path(request_record)
    expect(response).to have_http_status(:ok)
  end

  it "filters preference options by selected client and rejects cross-client preferences" do
    sign_in admin
    own_container = create(:container, :with_master_bl, master_bl: create(:master_bl, client: client))
    other_container = create(:container, :with_master_bl)

    get new_cargo_dispatch_request_path(client_id: client.id)
    expect(response.body).to include("Guía rápida", "total por embalaje o peso", "cargo-dispatch-request#filterContainers")
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('button[data-action="modal#open"]')).to be_present
    expect(document.at_css('dialog[aria-labelledby="quick-guide-title"]')).to be_present
    own_option = document.at_css(%(input[value="#{own_container.id}"]))
    other_option = document.at_css(%(input[value="#{other_container.id}"]))
    expect(own_option["data-client-id"]).to eq(client.id.to_s)
    expect(other_option["data-client-id"]).not_to eq(client.id.to_s)

    expect {
      post cargo_dispatch_requests_path, params: {
        cargo_dispatch_request: { client_id: client.id, destination: "Destino" },
        instruction: {
          criterion: "quantity", cargo_packaging_id: packaging.id, quantity: 5,
          preferred_container_ids: [ other_container.id ]
        }
      }
    }.not_to change(CargoDispatchRequest, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "separates the request summary from collapsed actions and inventory for the client and admin" do
    dispatch_request = CargoDispatchRequest.create!(client: client, requested_by: client_user, destination: "Destino")
    dispatch_request.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 6)
    trip = dispatch_request.trips.create!(origin_type: "general", transport_mode: "customer", transport_name: "Propio", created_by: client_user)

    [ client_user, admin ].each do |user|
      sign_in user
      get cargo_dispatch_request_path(dispatch_request)
      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('button[data-action="modal#open"]')).to be_present
      expect(document.at_css('dialog[aria-labelledby="quick-guide-title"]').text).to include(
        user.admin? ? "administración reserva las partidas" : "Puedes crear viajes de carga general"
      )
      expect(document.text).to include("Mercancía solicitada", "6 Cajas", "Viaje ##{trip.id}")
      expect(document.text).not_to include("Aún no hay viajes")
      [ "Agregar mercancía", "Crear viaje", "Consultar mercancía disponible en bodega" ].each do |label|
        details = document.css("details").find { |node| node.at_css("summary").text.include?(label) }
        expect(details).to be_present
        expect(details["open"]).to be_nil
      end
      expect(document.at_css(%(details form[action="#{add_instruction_cargo_dispatch_request_path(dispatch_request)}"]))).to be_present
      expect(document.at_css(%(details form[action="#{cargo_dispatch_request_cargo_dispatch_trips_path(dispatch_request)}"]))).to be_present
    end
  end

  it "adds a separate instruction without changing existing requested cargo" do
    dispatch_request = CargoDispatchRequest.create!(client: client, requested_by: client_user, destination: "Destino")
    original = dispatch_request.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 6)
    sign_in client_user

    expect {
      post add_instruction_cargo_dispatch_request_path(dispatch_request), params: {
        instruction: { criterion: "weight", weight_kg: 750 }
      }
    }.to change { dispatch_request.instructions.count }.by(1)
    expect(original.reload.quantity).to eq(6)
    expect(dispatch_request.instructions.last).to have_attributes(criterion: "weight", weight_kg: 750)
  end

  it "shows singular and plural packaging quantities in the request and trip" do
    dispatch_request = CargoDispatchRequest.create!(client: client, requested_by: client_user, destination: "Destino")
    roll = create(:cargo_packaging, name: "Rollo")
    dispatch_request.instructions.create!(criterion: "quantity", cargo_packaging: roll, quantity: 4)
    dispatch_request.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 1)
    trip = dispatch_request.trips.create!(origin_type: "general", transport_mode: "customer", transport_name: "Propio", created_by: client_user)
    sign_in admin

    [ cargo_dispatch_request_path(dispatch_request), cargo_dispatch_trip_path(trip) ].each do |path|
      get path
      expect(response.body).to include("4 Rollos", "1 Caja")
    end
  end

  it "shows a role- and origin-appropriate quick guide on trip details" do
    dispatch_request = CargoDispatchRequest.create!(client: client, requested_by: client_user, destination: "Destino")
    dispatch_request.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 6)
    own_trip = dispatch_request.trips.create!(origin_type: "general", transport_mode: "customer", transport_name: "Propio", created_by: client_user)
    carrier = create(:carrier)
    mbl_trip = dispatch_request.trips.create!(origin_type: "mbl", carrier: carrier, created_by: admin)
    carrier_user = create(:user, :transporte, carrier: carrier)

    [ [ admin, mbl_trip ], [ client_user, own_trip ], [ carrier_user, mbl_trip ], [ admin, own_trip ] ].each do |user, trip|
      sign_in user
      get cargo_dispatch_trip_path(trip)
      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('button[data-action="modal#open"]')).to be_present
      guide = document.at_css('dialog[aria-labelledby="quick-guide-title"]')
      expect(guide.text).to include("Guía rápida: viaje de despacho", "Garita escanea", "Las acciones visibles dependen")
      expect(guide.text).to include(trip.transport_mode == "customer" ? "cliente titular" : "transportista asignado")
      expect(guide.text.include?("Para reservar")).to eq(user.admin?)
      expect(guide.text.include?("En viajes de MBL")).to eq(user.admin? && trip.origin_type == "mbl")
    end
  end

  it "groups available MBL cargo by registration day and total balance without restricting manual choices" do
    dispatch_request = CargoDispatchRequest.create!(client: client, requested_by: client_user, destination: "Destino")
    instruction = dispatch_request.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 30)
    weight_instruction = dispatch_request.instructions.create!(criterion: "weight", weight_kg: 800)
    trip = dispatch_request.trips.create!(origin_type: "mbl", created_by: admin)
    other_trip = dispatch_request.trips.create!(origin_type: "mbl", created_by: admin)
    slot = create(:warehouse_slot)
    dates = [ "2026-10-10 23:30", "2026-10-11 08:00", "2026-10-11 17:00", "2026-10-11 14:00" ]
    mbls = dates.map { |date| create(:master_bl, client: client, created_at: Time.zone.parse(date)) }
    lines = mbls.zip([ 10, 8, 2, 2 ]).map do |master_bl, count|
      container = create(:container, :with_master_bl, master_bl: master_bl)
      manifest = create(:cargo_manifest, client: client, container: container)
      line = create(:cargo_item, cargo_manifest: manifest, cargo_packaging: packaging, quantity: count, weight_kg: nil)
      manifest.confirm_by!(admin)
      line.store_at!(slot, "A", admin)
      line
    end
    roll = create(:cargo_item, cargo_manifest: create(:cargo_manifest, client: client,
      container: create(:container, :with_master_bl, master_bl: mbls[1])), weight_kg: 800)
    roll.cargo_manifest.confirm_by!(admin)
    roll.store_at!(slot, "A", admin)
    CargoDispatchReservationService.call(trip: other_trip, selections: [ { instruction_id: instruction.id, cargo_item_id: lines[1].id, quantity: 3 } ])
    loaded_trip = dispatch_request.trips.create!(origin_type: "mbl", carrier: create(:carrier), created_by: admin)
    CargoDispatchReservationService.call(trip: loaded_trip, selections: [ { instruction_id: instruction.id, cargo_item_id: lines[1].id, quantity: 1 } ])
    loaded_trip.prepare!
    pass = loaded_trip.passes.create!(requested_by: admin, operator_name: "Operador", plate: "ABC123", unit_type: "sencillo")
    CargoDispatchOperationService.enter!(pass: pass, user: security)
    CargoDispatchOperationService.report!(trip: loaded_trip, allocation: loaded_trip.allocations.first, quantity: 1, user: operator)
    CargoDispatchOperationService.confirm!(trip: loaded_trip, user: admin)
    unlocated = create(:cargo_manifest, client: client, container: create(:container, :with_master_bl, master_bl: mbls[1]))
    create(:cargo_item, cargo_manifest: unlocated, cargo_packaging: packaging, quantity: 9, weight_kg: nil)
    unlocated.confirm_by!(admin)
    other_mbl = create(:master_bl)
    other_manifest = create(:cargo_manifest, client: other_mbl.client, container: create(:container, :with_master_bl, master_bl: other_mbl))
    other_line = create(:cargo_item, cargo_manifest: other_manifest, cargo_packaging: packaging, quantity: 1, weight_kg: nil)
    other_manifest.confirm_by!(admin)
    other_line.store_at!(slot, "A", admin)
    sign_in admin

    get cargo_dispatch_trip_path(trip)
    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    quantity_option = document.at_css(%(select[name="instruction_id"] option[value="#{instruction.id}"]))
    weight_option = document.at_css(%(select[name="instruction_id"] option[value="#{weight_instruction.id}"]))
    expect(quantity_option["data-criterion"]).to eq("quantity")
    expect(quantity_option["data-packaging-id"]).to eq(packaging.id.to_s)
    expect(weight_option["data-criterion"]).to eq("weight")
    groups = document.css("details[data-mbl-id]")
    expect(groups.map { |group| group["data-mbl-id"].to_i }).to eq([ mbls[0].id, mbls[3].id, mbls[2].id, mbls[1].id ])
    expect(groups.last.text).to include("5 unidades disponibles", "4 Cajas", "1 unidad")
    expect(groups.last.at_css(%(input[value="#{lines[1].id}"]))["data-packaging-id"]).to eq(packaging.id.to_s)
    expect(groups.last.at_css(%(input[value="#{roll.id}"]))["data-has-weight"]).to eq("true")
    expect(response.body).not_to include(other_mbl.number)

    post reserve_cargo_dispatch_trip_path(trip), params: { instruction_id: instruction.id, cargo_item_id: lines[2].id, quantity: 2 }
    expect(trip.allocations.sole).to have_attributes(cargo_item: lines[2], reserved_quantity: 2)
    get cargo_dispatch_trip_path(trip)
    expect(Nokogiri::HTML(response.body).css("details[data-mbl-id]").map { |group| group["data-mbl-id"].to_i }).not_to include(mbls[2].id)
  end

  it "reports an empty MBL selection without reserving unrelated or unconfirmed merchandise" do
    dispatch_request = CargoDispatchRequest.create!(client: client, requested_by: client_user, destination: "Destino")
    instruction = dispatch_request.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 2)
    trip = dispatch_request.trips.create!(origin_type: "mbl", created_by: admin)
    mbl = create(:master_bl, client: client)
    container = create(:container, :with_master_bl, master_bl: mbl)
    manifest = create(:cargo_manifest, client: client, container: container)
    create(:cargo_item, cargo_manifest: manifest, cargo_packaging: packaging, quantity: 2, weight_kg: nil)
    sign_in admin

    get cargo_dispatch_trip_path(trip)
    expect(response.body).to include("No hay mercancía disponible de MBL")
    expect(response.body).not_to include(%(data-mbl-id="#{mbl.id}"))
    post reserve_cargo_dispatch_trip_path(trip), params: { instruction_id: instruction.id, quantity: 1 }
    expect(flash[:alert]).to eq(I18n.t("cargo_dispatch.errors.invalid_item"))
    expect(trip.allocations).to be_empty
  end

  it "lets the owner remove one unreserved instruction, including the last one, without deleting inventory" do
    own_item = item
    dispatch_request = CargoDispatchRequest.create!(client: client, requested_by: client_user, destination: "Destino")
    container = create(:container, :with_master_bl, master_bl: create(:master_bl, client: client))
    first = dispatch_request.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 4, preferred_containers: [ container ])
    duplicate = dispatch_request.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 4)
    sign_in client_user

    get cargo_dispatch_request_path(dispatch_request)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css(%(form[action="#{remove_instruction_cargo_dispatch_request_path(dispatch_request, instruction_id: first.id)}"][data-turbo-confirm]))).to be_present

    delete remove_instruction_cargo_dispatch_request_path(dispatch_request, instruction_id: first.id)
    expect(response).to redirect_to(cargo_dispatch_request_path(dispatch_request))
    expect(flash[:notice]).to eq("Instrucción de mercancía eliminada.")
    expect(dispatch_request.instructions.reload).to contain_exactly(duplicate)
    expect(CargoDispatchInstructionContainer.where(cargo_dispatch_instruction_id: first.id)).to be_empty
    expect(own_item.reload.quantity).to eq(10)

    delete remove_instruction_cargo_dispatch_request_path(dispatch_request, instruction_id: duplicate.id)
    get cargo_dispatch_request_path(dispatch_request)
    expect(response.body).to include("No hay mercancía solicitada")
  end

  it "retains instructions with reservation history, including released reservations" do
    dispatch_request = CargoDispatchRequest.create!(client: client, requested_by: client_user, destination: "Destino")
    instruction = dispatch_request.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 3)
    trip = dispatch_request.trips.create!(origin_type: "general", transport_mode: "customer", transport_name: "Propio", created_by: client_user)
    CargoDispatchReservationService.call(trip: trip, selections: [ { cargo_item_id: item.id, instruction_id: instruction.id, quantity: 3 } ])
    sign_in admin

    %w[reserved released].each do |status|
      get cargo_dispatch_request_path(dispatch_request)
      expect(response.body).to include("No se puede eliminar: tiene historial de reservas o despacho.")
      expect(response.body).not_to include(remove_instruction_cargo_dispatch_request_path(dispatch_request, instruction_id: instruction.id))
      expect {
        delete remove_instruction_cargo_dispatch_request_path(dispatch_request, instruction_id: instruction.id)
      }.not_to change(CargoDispatchInstruction, :count)
      expect(flash[:alert]).to eq("No se puede eliminar: tiene historial de reservas o despacho.")
      trip.allocations.first.release! if status == "reserved"
    end
  end

  it "lets an administrator remove an unreserved instruction" do
    dispatch_request = CargoDispatchRequest.create!(client: client, requested_by: client_user, destination: "Destino")
    instruction = dispatch_request.instructions.create!(criterion: "weight", weight_kg: 100)
    sign_in admin

    expect {
      delete remove_instruction_cargo_dispatch_request_path(dispatch_request, instruction_id: instruction.id)
    }.to change(CargoDispatchInstruction, :count).by(-1)
    expect(response).to redirect_to(cargo_dispatch_request_path(dispatch_request))
  end

  it "does not delete another customer's instruction or an instruction from a different request" do
    dispatch_request = CargoDispatchRequest.create!(client: client, requested_by: client_user, destination: "Destino")
    instruction = dispatch_request.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 2)
    other_request = CargoDispatchRequest.create!(client: create(:client), requested_by: admin, destination: "Otro")
    other_instruction = other_request.instructions.create!(criterion: "weight", weight_kg: 100)
    sign_in client_user

    expect {
      delete remove_instruction_cargo_dispatch_request_path(other_request, instruction_id: other_instruction.id)
      delete remove_instruction_cargo_dispatch_request_path(dispatch_request, instruction_id: other_instruction.id)
    }.not_to change(CargoDispatchInstruction, :count)
    expect(CargoDispatchInstruction.exists?(instruction.id)).to be(true)
    expect(CargoDispatchInstruction.exists?(other_instruction.id)).to be(true)
  end

  it "shows the customer's available inventory by origin and packaging without exposing other clients" do
    own_item = item
    master_bl = create(:master_bl, client: client)
    container = create(:container, :with_master_bl, master_bl: master_bl)
    manifest = create(:cargo_manifest, client: client, container: container)
    roll = create(:cargo_item, cargo_manifest: manifest, weight_kg: 800)
    manifest.confirm_by!(admin)
    roll.store_at!(own_item.warehouse_slot, "A", admin)

    other_mbl = create(:master_bl)
    other_container = create(:container, :with_master_bl, master_bl: other_mbl)
    other_manifest = create(:cargo_manifest, client: other_mbl.client, container: other_container)
    other_item = create(:cargo_item, cargo_manifest: other_manifest)
    other_manifest.confirm_by!(admin)
    other_item.store_at!(own_item.warehouse_slot, "A", admin)

    dispatch_request = CargoDispatchRequest.create!(client: client, requested_by: client_user, destination: "Destino")
    instruction = dispatch_request.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 6)
    trip = dispatch_request.trips.create!(origin_type: "general", created_by: admin)
    CargoDispatchReservationService.call(trip: trip, selections: [ { cargo_item_id: own_item.id, instruction_id: instruction.id, quantity: 6 } ])

    sign_in client_user
    [ new_cargo_dispatch_request_path, cargo_dispatch_request_path(dispatch_request) ].each do |path|
      get path
      expect(response.body).to include(master_bl.number, container.number, "4 unidades disponibles",
        "4 unidades sin peso registrado", "800,000 kg")
      expect(response.body).not_to include(other_mbl.number, other_container.number)
    end
  end

  it "completes a partial general-cargo pickup with the customer's transport" do
    item
    sign_in client_user
    post cargo_dispatch_requests_path, params: {
      cargo_dispatch_request: { destination: "Destino" },
      instruction: { criterion: "quantity", cargo_packaging_id: packaging.id, quantity: 10 }
    }
    request_record = CargoDispatchRequest.last
    expect(response).to redirect_to(cargo_dispatch_request_path(request_record))
    get cargo_dispatch_request_path(request_record)
    expect(response).to have_http_status(:ok)
    post cargo_dispatch_request_cargo_dispatch_trips_path(request_record), params: {
      cargo_dispatch_trip: { origin_type: "general", transport_mode: "customer", transport_name: "Propio" }
    }
    trip = CargoDispatchTrip.last
    expect(response).to redirect_to(cargo_dispatch_trip_path(trip))

    sign_in admin
    post reserve_cargo_dispatch_trip_path(trip), params: {
      instruction_id: request_record.instructions.first.id, cargo_item_id: item.id, quantity: 10
    }
    expect(trip.allocations.count).to eq(1)
    get cargo_dispatch_trip_path(trip)
    expect(response).to have_http_status(:ok)
    patch prepare_cargo_dispatch_trip_path(trip)
    expect(trip.reload).to be_prepared

    sign_in client_user
    post issue_pass_cargo_dispatch_trip_path(trip), params: {
      cargo_dispatch_pass: { operator_name: "Operador", plate: "ABC123", unit_type: "sencillo" }
    }
    pass = trip.passes.last
    expect(response).to redirect_to(cargo_dispatch_pass_path(pass))
    get cargo_dispatch_pass_path(pass)
    expect(response).to have_http_status(:ok)
    get cargo_dispatch_pass_path(pass, format: :pdf)
    expect(response.media_type).to eq("application/pdf")

    sign_in security
    post scan_gate_pass_path, params: { token: pass.token }
    expect(response).to redirect_to(cargo_gate_pass_path(pass.token))
    get cargo_gate_pass_path(pass.token)
    follow_redirect!
    expect(response).to have_http_status(:ok)
    post complete_cargo_gate_movement_path(pass)
    expect(trip.reload).to be_in_yard
    expect(WorkOrder.where(container_id: item.cargo_manifest.container_id)).to be_empty

    sign_in operator
    get forklift_path
    expect(response).to have_http_status(:ok)
    post report_cargo_dispatch_path(trip), params: { allocation_id: trip.allocations.first.id, quantity: 4 }
    expect(trip.allocations.first.reload.reported_quantity).to eq(4)

    sign_in admin
    patch confirm_loading_cargo_dispatch_trip_path(trip)
    expect(trip.reload).to be_loaded
    expect(item.reload).to be_stored
    get tally_cargo_dispatch_trip_path(trip, format: :pdf)
    expect(pdf_text(response.body)).to include("Cantidad: 4", "Piezas cargadas: 4", "Salida pendiente")

    sign_in security
    get cargo_gate_pass_path(pass.token)
    expect(pass.reload.exit_scanned_at).to be_present
    post complete_cargo_gate_movement_path(pass)
    expect(trip.reload).to be_completed
    expect(pass.reload).to be_completed
    expect(trip.allocations.first.loaded_quantity).to eq(4)
  end

  it "does not allow another customer to create a trip for the request" do
    request_record = CargoDispatchRequest.create!(client: client, requested_by: admin, destination: "Destino")
    sign_in create(:user, :cliente, client: create(:client))
    expect {
      post cargo_dispatch_request_cargo_dispatch_trips_path(request_record), params: {
        cargo_dispatch_trip: { origin_type: "general", transport_mode: "customer", transport_name: "Otro" }
      }
    }.not_to change(CargoDispatchTrip, :count)
  end

  it "lets a client request an assigned carrier for general cargo" do
    request_record = CargoDispatchRequest.create!(client: client, requested_by: client_user, destination: "Destino")
    carrier = create(:carrier)
    sign_in client_user
    post cargo_dispatch_request_cargo_dispatch_trips_path(request_record), params: {
      cargo_dispatch_trip: { origin_type: "general", transport_mode: "assigned", carrier_id: carrier.id, transport_name: "" }
    }
    trip = request_record.trips.last
    expect(trip).to have_attributes(transport_mode: "assigned", carrier: nil)

    sign_in admin
    patch assign_carrier_cargo_dispatch_trip_path(trip), params: { carrier_id: carrier.id }
    expect(trip.reload.carrier).to eq(carrier)
  end

  it "reissues an expired pass without releasing the reservation" do
    item
    request_record = CargoDispatchRequest.create!(client: client, requested_by: client_user, destination: "Destino")
    instruction = request_record.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 3)
    trip = request_record.trips.create!(origin_type: "general", transport_mode: "customer", transport_name: "Propio", created_by: client_user)
    CargoDispatchReservationService.call(trip: trip, selections: [ { cargo_item_id: item.id, instruction_id: instruction.id, quantity: 3 } ])
    trip.prepare!
    previous = trip.passes.create!(requested_by: client_user, operator_name: "Operador", plate: "ABC123", unit_type: "sencillo")
    previous.update_columns(expires_at: 1.minute.ago)

    sign_in client_user
    post issue_pass_cargo_dispatch_trip_path(trip), params: {
      cargo_dispatch_pass: { operator_name: "Operador", plate: "ABC123", unit_type: "sencillo" }
    }

    expect(previous.reload).to be_expired
    expect(trip.passes.where(status: "active").count).to eq(1)
    expect(trip.allocations.first).to be_reserved
  end

  it "allows an assigned carrier to pick up a roll from an MBL by target weight" do
    master_bl = create(:master_bl, client: client)
    container = create(:container, :with_master_bl, master_bl: master_bl)
    manifest = create(:cargo_manifest, client: client, container: container)
    roll = create(:cargo_item, cargo_manifest: manifest, weight_kg: 800, generate_qr: true)
    manifest.confirm_by!(admin)
    roll.store_at!(create(:warehouse_slot), "A", admin)
    request_record = CargoDispatchRequest.create!(client: client, requested_by: client_user, destination: "Destino")
    instruction = request_record.instructions.create!(
      criterion: "weight", weight_kg: 750, preferred_containers: [ container ]
    )
    carrier = create(:carrier)
    trip = request_record.trips.create!(origin_type: "mbl", transport_mode: "assigned", carrier: carrier, created_by: admin)

    sign_in admin
    get cargo_dispatch_trip_path(trip)
    expect(response.body).to include(master_bl.number, container.number, "800,000", "Preferidos: #{container.number}")
    post reserve_cargo_dispatch_trip_path(trip), params: { instruction_id: instruction.id, cargo_item_id: roll.id, quantity: 1 }
    get cargo_dispatch_trip_path(trip)
    expect(response.body).to include("750,000", "800,000", "50,000")
    patch prepare_cargo_dispatch_trip_path(trip)

    sign_in create(:user, :transporte, carrier: carrier)
    post issue_pass_cargo_dispatch_trip_path(trip), params: {
      cargo_dispatch_pass: { operator_name: "Operador", plate: "ABC123", unit_type: "sencillo" }
    }
    pass = trip.passes.last
    expect(pass).to be_active

    sign_in security
    get cargo_gate_pass_path(pass.token)
    post complete_cargo_gate_movement_path(pass)
    sign_in operator
    post report_cargo_dispatch_path(trip), params: { code: roll.qr_token, quantity: 1 }
    sign_in admin
    patch confirm_loading_cargo_dispatch_trip_path(trip)
    expect(roll.reload).to be_dispatched
    get tally_cargo_dispatch_trip_path(trip, format: :pdf)
    expect(pdf_text(response.body)).to include(master_bl.number, container.number, "800,000 kg", "Salida pendiente")
  end

  it "does not allow another carrier to request or view a pass" do
    carrier = create(:carrier)
    request_record = CargoDispatchRequest.create!(client: client, requested_by: admin, destination: "Destino")
    trip = request_record.trips.create!(origin_type: "mbl", transport_mode: "assigned", carrier: carrier, created_by: admin)
    sign_in create(:user, :transporte, carrier: create(:carrier))

    post issue_pass_cargo_dispatch_trip_path(trip), params: {
      cargo_dispatch_pass: { operator_name: "Operador", plate: "ABC123", unit_type: "sencillo" }
    }
    expect(trip.passes).to be_empty
  end

  it "counts only completed exits, including historical trips, and shows new delivery details" do
    request_record = CargoDispatchRequest.create!(client: client, requested_by: admin, destination: "Destino")
    instruction = request_record.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 10)
    old_trip, old_pass = loaded_trip(request_record, instruction, 3, historical: true)
    new_trip, new_pass = loaded_trip(request_record, instruction, 4)
    sign_in admin

    finish_trip(old_pass)
    get cargo_manifest_cargo_item_path(item.cargo_manifest, item)
    expect(response.body).to include("Entrega parcial: 3 unidades entregadas")
    expect(response.body).not_to include("Viaje ##{old_trip.id}:")
    expect(CargoDispatchAllocation.delivered.where(cargo_item: item).sum(:loaded_quantity)).to eq(3)

    finish_trip(new_pass)
    CargoDispatchOperationService.exit!(pass: new_pass, user: security)
    expect(new_trip.events.where(event: "exited").count).to eq(1)
    get cargo_manifest_path(item.cargo_manifest)
    expect(response.body).to include("Entrega parcial: 7 unidades entregadas", "Viaje ##{new_trip.id}:", "Propio")
    expect(response.body).not_to include("Viaje ##{old_trip.id}:")
    get cargo_dispatch_trip_path(new_trip)
    expect(response.body).to include("Salida confirmada:", "Entregado: 4 unidades")

    last_trip, last_pass = loaded_trip(request_record, instruction, 3)
    finish_trip(last_pass)
    get cargo_manifest_cargo_item_path(item.cargo_manifest, item)
    expect(response.body).to include("Entregado: 10 unidades", "Viaje ##{last_trip.id}:", "No disponible")
  end

  it "generates the tally after loading and retains the confirmation time after exit" do
    request_record = CargoDispatchRequest.create!(client: client, requested_by: admin, destination: "Destino")
    instruction = request_record.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 10)
    trip, pass = loaded_trip(request_record, instruction, 4, expired_pass: true)
    sign_in client_user

    get tally_cargo_dispatch_trip_path(trip, format: :pdf)
    expect(response.media_type).to eq("application/pdf")
    confirmation = I18n.l(trip.events.find_by!(event: "loading_confirmed").created_at.in_time_zone, format: :long)
    expect(pdf_text(response.body)).to include("Confirmación de carga: #{confirmation}", "Salida pendiente", "Cantidad: 4", "Peso conocido total: No disponible")

    finish_trip(pass)
    get tally_cargo_dispatch_trip_path(trip, format: :pdf)
    expect(pdf_text(response.body)).to include("Confirmación de carga: #{confirmation}", "Salida confirmada:")
    expect(pdf_text(response.body)).not_to include("Salida pendiente")

    sign_in create(:user, :cliente, client: create(:client))
    get tally_cargo_dispatch_trip_path(trip, format: :pdf)
    expect(response).not_to have_http_status(:ok)
  end

  it "rejects photo uploads before exit or by non-admins and protects photo downloads" do
    request_record = CargoDispatchRequest.create!(client: client, requested_by: admin, destination: "Destino")
    instruction = request_record.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 10)
    trip, pass = loaded_trip(request_record, instruction, 2)
    photo = -> { fixture_file_upload(Rails.root.join("public/icon.png"), "image/png") }
    sign_in admin
    post exit_photos_cargo_dispatch_trip_path(trip), params: { photos: [ photo.call ] }
    expect(trip.exit_photos).not_to be_attached

    finish_trip(pass)
    post exit_photos_cargo_dispatch_trip_path(trip), params: { photos: [ fixture_file_upload(Rails.root.join("spec/fixtures/files/mbl.pdf"), "image/png") ] }
    expect(trip.exit_photos).not_to be_attached
    expect(flash[:alert]).to be_present
    post exit_photos_cargo_dispatch_trip_path(trip), params: { photos: Array.new(Container::MAX_PHOTOS_PER_UPLOAD + 1) { photo.call } }
    expect(trip.exit_photos).not_to be_attached
    expect(flash[:alert]).to be_present
    post exit_photos_cargo_dispatch_trip_path(trip), params: { photos: [ photo.call ] }
    expect(trip.exit_photos.reload.count).to eq(1)
    attachment = trip.exit_photos_attachments.first

    sign_in client_user
    get exit_photo_cargo_dispatch_trip_path(trip, photo_id: attachment.id)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/png")
    delete exit_photo_cargo_dispatch_trip_path(trip, photo_id: attachment.id)
    expect(trip.exit_photos.reload.count).to eq(1)

    sign_in create(:user, :cliente, client: create(:client))
    get exit_photo_cargo_dispatch_trip_path(trip, photo_id: attachment.id)
    expect(response).not_to have_http_status(:ok)

    sign_in admin
    delete exit_photo_cargo_dispatch_trip_path(trip, photo_id: attachment.id)
    expect(trip.exit_photos.reload.count).to eq(0)
  end

  it "shows the reason on a tally for a trip with no cargo, without recording a delivery" do
    request_record = CargoDispatchRequest.create!(client: client, requested_by: admin, destination: "Destino")
    instruction = request_record.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 2)
    trip = request_record.trips.create!(origin_type: "general", transport_mode: "customer", transport_name: "Propio", created_by: admin)
    CargoDispatchReservationService.call(trip: trip, selections: [ { cargo_item_id: item.id, instruction_id: instruction.id, quantity: 2 } ])
    trip.prepare!
    pass = trip.passes.create!(requested_by: admin, operator_name: "Operador", plate: "ABC123", unit_type: "sencillo")
    CargoDispatchOperationService.enter!(pass: pass, user: security)
    CargoDispatchOperationService.confirm!(trip: trip, user: admin, reason: "Sin mercancía")
    finish_trip(pass)
    sign_in admin

    get tally_cargo_dispatch_trip_path(trip, format: :pdf)
    expect(pdf_text(response.body)).to include("Sin carga. Motivo: Sin mercancía", "Confirmación de carga:", "Salida confirmada:")
    expect(CargoDispatchAllocation.delivered.where(cargo_item: item)).to be_empty

    trip.update!(exit_evidence_enabled: false)
    get tally_cargo_dispatch_trip_path(trip, format: :pdf)
    expect(response).not_to have_http_status(:ok)
  end

  it "renders MBL origins and long lists of confirmed cargo across multiple PDF pages" do
    master_bl = create(:master_bl, client: client)
    container = create(:container, :with_master_bl, master_bl: master_bl)
    manifest = create(:cargo_manifest, client: client, container: container)
    items = 22.times.map do |index|
      create(:cargo_item, cargo_manifest: manifest, cargo_packaging: packaging, quantity: 1, weight_kg: nil,
        description: "Mercancía número #{index}", origin_identifier: "PARTE-#{index}")
    end
    manifest.confirm_by!(admin)
    slot = create(:warehouse_slot)
    items.each { |line| line.store_at!(slot, "A", admin) }
    request_record = CargoDispatchRequest.create!(client: client, requested_by: admin, destination: "Destino")
    instruction = request_record.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: items.size)
    trip = request_record.trips.create!(origin_type: "mbl", carrier: create(:carrier), created_by: admin)
    CargoDispatchReservationService.call(trip: trip, selections: items.map { |line| { cargo_item_id: line.id, instruction_id: instruction.id, quantity: 1 } })
    trip.prepare!
    pass = trip.passes.create!(requested_by: admin, operator_name: "Operador", plate: "ABC123", unit_type: "sencillo")
    CargoDispatchOperationService.enter!(pass: pass, user: security)
    trip.allocations.each { |allocation| CargoDispatchOperationService.report!(trip: trip, allocation: allocation, quantity: 1, user: operator) }
    CargoDispatchOperationService.confirm!(trip: trip, user: admin)
    sign_in admin

    get tally_cargo_dispatch_trip_path(trip, format: :pdf)
    expect(response.body.scan(%r{/Type\s*/Page\b}).size).to be > 1
    expect(pdf_text(response.body)).to include(master_bl.number, container.number, "PARTE-0", "PARTE-21", "Piezas cargadas: 22")
    finish_trip(pass)
    get cargo_dispatch_trip_path(trip)
    expect(response.body).to include(master_bl.number, container.number, "PARTE-21")
    sign_in create(:user, :transporte, carrier: trip.carrier)
    get tally_cargo_dispatch_trip_path(trip, format: :pdf)
    expect(response).to have_http_status(:ok)
    sign_in create(:user, :transporte, carrier: create(:carrier))
    get tally_cargo_dispatch_trip_path(trip, format: :pdf)
    expect(response).not_to have_http_status(:ok)
  end

  def loaded_trip(request_record, instruction, quantity, historical: false, expired_pass: false)
    trip = request_record.trips.create!(origin_type: "general", transport_mode: "customer", transport_name: "Propio",
      created_by: admin, exit_evidence_enabled: !historical)
    CargoDispatchReservationService.call(trip: trip, selections: [ { cargo_item_id: item.id, instruction_id: instruction.id, quantity: quantity } ])
    trip.prepare!
    if expired_pass
      previous = trip.passes.create!(requested_by: admin, operator_name: "Anterior", plate: "XYZ123", unit_type: "sencillo")
      previous.update!(expires_at: 1.minute.ago)
      previous.expire!
    end
    pass = trip.passes.create!(requested_by: admin, operator_name: "Operador", plate: "ABC123", unit_type: "sencillo")
    CargoDispatchOperationService.enter!(pass: pass, user: security)
    CargoDispatchOperationService.report!(trip: trip, allocation: trip.allocations.first, quantity: quantity, user: operator)
    CargoDispatchOperationService.confirm!(trip: trip, user: admin)
    [ trip.reload, pass.reload ]
  end

  def finish_trip(pass)
    pass.update!(exit_scanned_at: Time.current)
    CargoDispatchOperationService.exit!(pass: pass, user: security)
  end

  def pdf_text(pdf)
    pdf.scan(/<([0-9a-f]+)>/i).flatten.map { |hex| [ hex ].pack("H*").force_encoding("Windows-1252").encode("UTF-8") }.join
  end
end
