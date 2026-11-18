require "rails_helper"

RSpec.describe "MasterBls", type: :request do
  let!(:record) { create(:master_bl) }
  let(:client) { create(:client) }

  context "as admin" do
    before { sign_in create(:user, :admin) }

    it "lists records" do
      get master_bls_path
      expect(response.body).to include(record.number, master_bl_path(record))
    end

    it "orders by registration date and distinguishes missing capture from available cargo" do
      record.update!(created_at: 2.days.ago)
      newer = create(:master_bl, client: record.client, created_at: 1.day.ago)
      container = create(:container, :with_master_bl, master_bl: newer)
      manifest = create(:cargo_manifest, client: record.client, container: container)
      line = create(:cargo_item, cargo_manifest: manifest)
      manifest.confirm_by!(create(:user, :admin))
      line.store_at!(create(:warehouse_slot), "A", create(:user, :admin))

      get master_bls_path
      expect(response.body.index(record.number)).to be < response.body.index(newer.number)
      expect(response.body).to include("Sin captura", "1 unidad disponible")

      get master_bls_path, params: { availability: "available" }
      expect(response.body).to include(newer.number)
      expect(response.body).not_to include(record.number)

      get master_bls_path, params: { from_date: 1.day.ago.to_date.iso8601 }
      expect(response.body).to include(newer.number)
      expect(response.body).not_to include(record.number)
    end

    it "orders available MBLs by remaining unreserved units" do
      older = create(:master_bl, client: record.client, created_at: 2.days.ago)
      newer = create(:master_bl, client: record.client, created_at: 1.day.ago)
      packaging = create(:cargo_packaging, :box)
      admin = create(:user, :admin)
      items = [ [ older, 8 ], [ newer, 2 ] ].map do |master_bl, quantity|
        container = create(:container, :with_master_bl, master_bl: master_bl)
        manifest = create(:cargo_manifest, client: master_bl.client, container: container)
        line = create(:cargo_item, cargo_manifest: manifest, cargo_packaging: packaging, quantity: quantity, weight_kg: nil)
        manifest.confirm_by!(admin)
        line.store_at!(create(:warehouse_slot), "A", admin)
        line
      end
      dispatch_request = CargoDispatchRequest.create!(client: record.client, requested_by: admin, destination: "Destino")
      instruction = dispatch_request.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 5)
      trip = dispatch_request.trips.create!(origin_type: "mbl", created_by: admin)
      CargoDispatchReservationService.call(trip: trip, selections: [ { cargo_item_id: items.first.id, instruction_id: instruction.id, quantity: 5 } ])

      get master_bls_path, params: { availability: "available", sort: "available" }
      expect(response.body.index(newer.number)).to be < response.body.index(older.number)
      expect(response.body).not_to include(record.number)
      expect(response.body).to include("5 unidades reservadas", "3 unidades disponibles")
      mobile_cards = Nokogiri::HTML(response.body).at_css('ul[class*="md:hidden"]')
      older_card = mobile_cards.css("li").find { |card| card.text.include?(older.number) }
      expect(older_card.text).to include("5 unidades reservadas", "3 unidades disponibles", "8 unidades")
    end

    it "shows a record" do
      get master_bl_path(record)
      expect(response.body).to include(record.number, record.client.name)

      document_button = Nokogiri::HTML(response.body).at_css('button[data-direct-upload-target="submit"]')
      containers_button = Nokogiri::HTML(response.body).at_css('button[data-file-required-target="submit"]')
      expect(document_button["disabled"]).to be_present
      expect(containers_button["disabled"]).to be_present
    end

    it "creates a record linked to a client" do
      expect { post master_bls_path, params: { master_bl: { number: "cosu999", client_id: client.id } } }.to change(MasterBl, :count).by(1)
      expect(MasterBl.last).to have_attributes(number: "COSU999", client: client)
      expect(flash[:notice]).to eq(I18n.t("flash.master_bls.create"))
    end

    it "rejects a duplicate number" do
      expect { post master_bls_path, params: { master_bl: { number: record.number, client_id: client.id } } }.not_to change(MasterBl, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "updates a record" do
      patch master_bl_path(record), params: { master_bl: { number: "NUEVO1" } }
      expect(record.reload.number).to eq("NUEVO1")
    end

    it "deletes a record" do
      expect { delete master_bl_path(record) }.to change(MasterBl, :count).by(-1)
    end

    it "does not delete an MBL that has containers" do
      create(:container, :with_master_bl, master_bl: record)
      expect { delete master_bl_path(record) }.not_to change(MasterBl, :count)
      expect(response).to redirect_to(master_bl_path(record))
      expect(flash[:alert]).to eq(I18n.t("flash.master_bls.destroy_restricted"))
      expect(flash[:notice]).to be_nil
    end

    it "lists the containers of the MBL on the detail page" do
      container = create(:container, :with_master_bl, master_bl: record)
      other = create(:container, :with_master_bl)
      get master_bl_path(record)
      expect(response.body).to include(container.number, template_master_bl_path(record), import_master_bl_path(record))
      expect(response.body).not_to include(other.number)
    end

    it "offers creating a container preselecting the MBL and returns to it" do
      get master_bl_path(record)
      expect(response.body).to include(new_container_path(container: { master_bl_id: record.id }).gsub("&", "&amp;"))

      get new_container_path(container: { master_bl_id: record.id })
      expect(response.body).to include(%(value="#{record.id}"), record.number)
      expect(response.body).not_to include('name="container[status]"')

      post containers_path, params: { container: { number: "MSKU1234567", size: 20, container_type: "standard", master_bl_id: record.id } }
      expect(response).to redirect_to(master_bl_path(record))
      expect(record.containers.last).to be_activo
    end

    it "downloads the Excel template" do
      get template_master_bl_path(record)
      expect(response.media_type).to eq(ContainerSpreadsheet::CONTENT_TYPE)
      expect(response.headers["Content-Disposition"]).to include("#{record.number}.xlsx")
    end

    it "imports containers from an Excel file" do
      file = build_xlsx([ [ "MSKU1234567", 20, "Estándar" ], [ "TGHU7654321", 40, "HQ" ] ])
      expect { post import_master_bl_path(record), params: { file: file } }.to change { record.containers.count }.by(2)
      expect(response).to redirect_to(master_bl_path(record))
      expect(flash[:notice]).to eq(I18n.t("flash.master_bls.import", count: 2))
    end

    it "shows row errors and imports nothing when the file is invalid" do
      file = build_xlsx([ [ "MSKU1234567", 20, "HQ" ], [ "MALO", 20, "HQ" ] ])
      expect { post import_master_bl_path(record), params: { file: file } }.not_to change(Container, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Fila 3")
    end

    it "requires a file" do
      post import_master_bl_path(record)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("container_import.errors.no_file"))
    end

    it "renders forms without missing translations" do
      [ new_master_bl_path, edit_master_bl_path(record), master_bls_path ].each do |path|
        get path
        expect(response.body).not_to include("translation missing", "translation_missing")
      end
    end
  end

  context "as non-admin" do
    before { sign_in create(:user, :cliente) }

    it "cannot import or download the template" do
      get template_master_bl_path(record)
      expect(response).not_to have_http_status(:ok)
      expect { post import_master_bl_path(record), params: { file: build_xlsx([ [ "MSKU1234567", 20, "HQ" ] ]) } }.not_to change(Container, :count)
    end

    it "cannot create" do
      expect { post master_bls_path, params: { master_bl: { number: "X1", client_id: client.id } } }.not_to change(MasterBl, :count)
    end
  end

  it "requires login" do
    get master_bls_path
    expect(response).to redirect_to(new_user_session_path)
  end
end
