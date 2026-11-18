class CargoDispatchGateController < ApplicationController
  before_action { authorize MovementPass, :gate? }

  def open
    pass = CargoDispatchPass.find_by(token: params[:token])
    return redirect_to gate_path, alert: t("gate.errors.pass_not_found") unless pass

    trip = pass.cargo_dispatch_trip
    trip.with_lock do
      pass = trip.passes.lock.find(pass.id)
      pass.expire! if pass.may_expire?
      if pass.usable? && pass.entered_at? && trip.loaded? && !pass.exit_scanned_at?
        pass.update!(exit_scanned_at: Time.current)
      end
    end
    return redirect_to gate_path, alert: t("cargo_dispatch.errors.pass_unusable") unless pass.usable?
    if pass.entered_at? && !pass.exit_scanned_at?
      return redirect_to gate_path, alert: t("cargo_dispatch.errors.loading_unconfirmed")
    end

    redirect_to cargo_gate_movement_path(pass)
  end

  def show
    @pass = CargoDispatchPass.find(params[:id])
    return redirect_to gate_path, alert: t("cargo_dispatch.errors.pass_unusable") unless @pass.usable?
    if @pass.entered_at? && !@pass.exit_scanned_at?
      redirect_to gate_path, alert: t("cargo_dispatch.errors.exit_scan_required")
    end
  end

  def complete
    pass = CargoDispatchPass.find(params[:id])
    if pass.entered_at?
      CargoDispatchOperationService.exit!(pass: pass, user: current_user)
      redirect_to gate_path, notice: t("cargo_dispatch.flash.exited")
    else
      CargoDispatchOperationService.enter!(pass: pass, user: current_user)
      redirect_to gate_path, notice: t("cargo_dispatch.flash.entered")
    end
  rescue CargoDispatchOperationService::Error => error
    redirect_to gate_path, alert: error.message
  end
end
