class CargoDispatchForkliftController < ApplicationController
  def report
    trip = CargoDispatchTrip.find(params[:id])
    authorize trip, :report?
    allocation = find_allocation(trip)
    return redirect_to forklift_path, alert: t("cargo_dispatch.errors.invalid_item") unless allocation

    CargoDispatchOperationService.report!(trip: trip, allocation: allocation, quantity: params[:quantity], user: current_user)
    redirect_to forklift_path, notice: t("cargo_dispatch.flash.reported")
  rescue CargoDispatchOperationService::Error => error
    redirect_to forklift_path, alert: error.message
  end

  private

  def find_allocation(trip)
    scope = trip.allocations.where(status: "reserved")
    return scope.find_by(id: params[:allocation_id]) if params[:allocation_id].present?

    token = params[:code].to_s.strip
    token = Rack::Utils.parse_query(URI.parse(token).query.to_s)["token"].to_s if token.match?(%r{\Ahttps?://}i)
    matches = scope.joins(:cargo_item).where(cargo_items: { qr_token: token }).limit(2).to_a
    matches.one? ? matches.first : nil
  rescue URI::InvalidURIError
    nil
  end
end
