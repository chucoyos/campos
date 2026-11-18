class CargoDispatchPassesController < ApplicationController
  def show
    @pass = CargoDispatchPass.find(params[:id])
    authorize @pass
    @gate_url = cargo_gate_pass_url(@pass.token) if @pass.usable?
    respond_to do |format|
      format.html
      format.pdf do
        return redirect_to(cargo_dispatch_pass_path(@pass), alert: t("cargo_dispatch.errors.pass_unusable")) unless @gate_url

        send_data CargoDispatchPassPdf.new(@pass, gate_url: @gate_url).render,
          filename: "pase-mercancia-#{@pass.id}.pdf", type: "application/pdf", disposition: "inline"
      end
    end
  end

  def cancel
    pass = CargoDispatchPass.find(params[:id])
    authorize pass
    trip = pass.cargo_dispatch_trip
    trip.with_lock do
      pass = trip.passes.lock.find(pass.id)
      pass.cancel!
      trip.events.create!(user: current_user, cargo_dispatch_pass: pass, event: "pass_cancelled")
    end
    redirect_to cargo_dispatch_trip_path(trip), notice: t("cargo_dispatch.flash.pass_cancelled")
  rescue AASM::InvalidTransition
    redirect_to cargo_dispatch_trip_path(trip), alert: t("cargo_dispatch.errors.pass_unusable")
  end
end
