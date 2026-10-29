require "rails_helper"

RSpec.describe "Diálogo de confirmación", type: :request do
  it "incluye el diálogo Material 3 en el layout y usa el tono operativo en la grúa" do
    create(:work_order)
    sign_in create(:user, :grua)

    get crane_path

    html = Nokogiri::HTML(response.body)
    expect(html.at_css("dialog#confirm-dialog").text).to include("Confirmar acción", "Cancelar", "Confirmar")
    expect(html.at_css("form[data-turbo-confirm-tone=success]")).to be_present
  end
end
