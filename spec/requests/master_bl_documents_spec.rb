require "rails_helper"

RSpec.describe "Documento del MBL", type: :request do
  let(:master_bl) { create(:master_bl) }
  let(:pdf) { fixture_file_upload(Rails.root.join("spec/fixtures/files/mbl.pdf"), "application/pdf") }

  before { sign_in create(:user, :admin) }

  it "sube, muestra, descarga y elimina el documento" do
    patch upload_document_master_bl_path(master_bl), params: { document: pdf }
    expect(response).to redirect_to(master_bl_path(master_bl))
    expect(master_bl.reload.document).to be_attached

    get master_bl_path(master_bl)
    expect(response.body).to include("mbl.pdf", "Reemplazar documento")

    get document_master_bl_path(master_bl)
    expect(response).to have_http_status(:redirect)
    expect(response.location).to include("mbl.pdf")

    delete remove_document_master_bl_path(master_bl)
    expect(response).to redirect_to(master_bl_path(master_bl))
    perform_enqueued_jobs if respond_to?(:perform_enqueued_jobs)
  end

  it "rechaza archivos que no son PDF y conserva el documento previo" do
    master_bl.document.attach(io: StringIO.new("%PDF-1.4"), filename: "previo.pdf", content_type: "application/pdf")
    txt = Rack::Test::UploadedFile.new(StringIO.new("hola"), "text/plain", original_filename: "nota.txt")

    patch upload_document_master_bl_path(master_bl), params: { document: txt }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("debe ser un archivo PDF", "previo.pdf")
    expect(master_bl.reload.document.filename.to_s).to eq("previo.pdf")
  end

  it "pide seleccionar un archivo" do
    patch upload_document_master_bl_path(master_bl)
    expect(response).to redirect_to(master_bl_path(master_bl))
    expect(flash[:alert]).to eq("Selecciona un archivo PDF.")
  end

  it "avisa si no hay documento para descargar" do
    get document_master_bl_path(master_bl)
    expect(response).to redirect_to(master_bl_path(master_bl))
  end

  it "no permite a usuarios no administradores" do
    sign_in create(:user, :cliente)
    patch upload_document_master_bl_path(master_bl), params: { document: pdf }
    expect(master_bl.reload.document).not_to be_attached
  end
end
