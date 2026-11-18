class CargoDispatchTripsController < ApplicationController
  def index
    authorize CargoDispatchTrip
    scope = policy_scope(CargoDispatchTrip).includes(:carrier).order(created_at: :desc)
    scope = scope.includes(cargo_dispatch_request: :client) if current_user.admin? || current_user.client_member?
    @pagy, @trips = paginate(scope)
  end

  def show
    load_trip
    authorize @trip
    @allocations = @trip.allocations.includes(cargo_item: :cargo_packaging).order(:id)
    if policy(@trip).reserve? && @trip.pending?
      @carriers = Carrier.order(:name) if @trip.transport_mode == "assigned"
      instructions = @trip.cargo_dispatch_request.instructions
      @instructions = instructions.includes(:preferred_containers).order(:id)
      @instructions = @instructions.includes(:container) if instructions.where.not(container_id: nil).exists?
      @instructions = @instructions.includes(:cargo_packaging) if instructions.where(criterion: "quantity").exists?
      items = CargoItem.joins(:cargo_manifest).where(status: "stored",
        cargo_manifests: { client_id: @trip.cargo_dispatch_request.client_id, status: "confirmed" })
      @items = if @trip.origin_type == "mbl"
        items.where.not(cargo_manifests: { container_id: nil }).order(:id).to_a
      else
        items.where(cargo_manifests: { container_id: nil }).includes(:cargo_packaging, :warehouse_slot).order(:id).to_a
      end
      totals = CargoDispatchAllocation.where(cargo_item_id: @items.map(&:id))
      @reserved = totals.where(status: "reserved").group(:cargo_item_id).sum(:reserved_quantity)
      @loaded = totals.where(status: "confirmed").group(:cargo_item_id).sum(:loaded_quantity)
      if @trip.origin_type == "mbl"
        @mbl_groups = available_mbl_groups
        @allocated_instructions_by_item = @allocations.group_by(&:cargo_item_id)
      end
    end
    if current_user.admin?
      @weight_instructions = @trip.cargo_dispatch_request.instructions.where(criterion: "weight")
      @weight_totals = CargoDispatchAllocation.joins(:cargo_item)
        .where(cargo_dispatch_instruction_id: @weight_instructions.select(:id), status: %w[reserved confirmed])
        .group(:cargo_dispatch_instruction_id)
        .sum("cargo_items.weight_kg * CASE WHEN cargo_dispatch_allocations.status = 'reserved' THEN cargo_dispatch_allocations.reserved_quantity ELSE cargo_dispatch_allocations.loaded_quantity END")
    end
  end

  def create
    request_record = CargoDispatchRequest.find(params[:cargo_dispatch_request_id])
    @trip = request_record.trips.build(trip_params.merge(created_by: current_user))
    authorize @trip
    if @trip.save
      redirect_to cargo_dispatch_trip_path(@trip), notice: t("cargo_dispatch.flash.trip_created")
    else
      redirect_back_or_to cargo_dispatch_request_path(request_record), alert: @trip.errors.full_messages.to_sentence
    end
  end

  def reserve
    load_trip
    authorize @trip
    CargoDispatchReservationService.call(trip: @trip, selections: [
      { instruction_id: params[:instruction_id], cargo_item_id: params[:cargo_item_id], quantity: params[:quantity] }
    ])
    redirect_to cargo_dispatch_trip_path(@trip), notice: t("cargo_dispatch.flash.reserved")
  rescue CargoDispatchReservationService::Error, ActiveRecord::RecordInvalid => error
    redirect_to cargo_dispatch_trip_path(@trip), alert: error.message
  end

  def assign_carrier
    load_trip
    authorize @trip
    carrier = Carrier.find(params[:carrier_id])
    @trip.with_lock do
      unless @trip.pending? && @trip.transport_mode == "assigned"
        raise CargoDispatchOperationService::Error, t("cargo_dispatch.errors.cannot_assign_carrier")
      end

      @trip.update!(carrier: carrier)
      @trip.events.create!(user: current_user, event: "carrier_assigned", details: carrier.name)
    end
    redirect_to cargo_dispatch_trip_path(@trip), notice: t("cargo_dispatch.flash.carrier_assigned")
  rescue CargoDispatchOperationService::Error, ActiveRecord::RecordInvalid => error
    redirect_to cargo_dispatch_trip_path(@trip), alert: error.message
  end

  def prepare
    load_trip
    authorize @trip
    @trip.with_lock do
      @trip.prepare!
      request_record = @trip.cargo_dispatch_request
      request_record.with_lock { request_record.start! if request_record.may_start? }
    end
    redirect_to cargo_dispatch_trip_path(@trip), notice: t("cargo_dispatch.flash.prepared")
  rescue AASM::InvalidTransition
    redirect_to cargo_dispatch_trip_path(@trip), alert: t("cargo_dispatch.errors.cannot_prepare")
  end

  def confirm_loading
    load_trip
    authorize @trip
    CargoDispatchOperationService.confirm!(trip: @trip, user: current_user, reason: params[:reason])
    redirect_to cargo_dispatch_trip_path(@trip), notice: t("cargo_dispatch.flash.confirmed")
  rescue CargoDispatchOperationService::Error => error
    redirect_to cargo_dispatch_trip_path(@trip), alert: error.message
  end

  def cancel
    load_trip
    authorize @trip
    CargoDispatchOperationService.cancel!(trip: @trip, user: current_user)
    redirect_to cargo_dispatch_trip_path(@trip), notice: t("cargo_dispatch.flash.trip_cancelled")
  rescue CargoDispatchOperationService::Error => error
    redirect_to cargo_dispatch_trip_path(@trip), alert: error.message
  end

  def issue_pass
    load_trip
    authorize @trip
    pass = nil
    @trip.with_lock do
      raise CargoDispatchOperationService::Error, t("cargo_dispatch.errors.trip_not_prepared") unless @trip.prepared?

      previous = @trip.passes.where(status: "active").lock.first
      previous.expire! if previous&.overdue?
      raise CargoDispatchOperationService::Error, t("cargo_dispatch.errors.active_pass") if previous&.active?

      pass = @trip.passes.create!(pass_params.merge(requested_by: current_user))
      @trip.events.create!(user: current_user, cargo_dispatch_pass: pass, event: "pass_issued")
    end
    redirect_to cargo_dispatch_pass_path(pass), notice: t("cargo_dispatch.flash.pass_issued")
  rescue CargoDispatchOperationService::Error, ActiveRecord::RecordInvalid => error
    redirect_to cargo_dispatch_trip_path(@trip), alert: error.message
  end

  private

  def available_mbl_groups
    available_items = @items.select { |item| available_quantity(item).positive? }
    ActiveRecord::Associations::Preloader.new(
      records: available_items, associations: [ :cargo_packaging, :warehouse_slot, { cargo_manifest: { container: :master_bl } } ]
    ).call
    available_items.group_by { |item| item.cargo_manifest.container.master_bl }.map do |master_bl, items|
      {
        master_bl: master_bl,
        items: items,
        available: items.sum { |item| available_quantity(item) },
        packagings: items.group_by(&:cargo_packaging).transform_values { |lines| lines.sum { |item| available_quantity(item) } }
      }
    end.sort_by { |group| [ group[:master_bl].created_at.in_time_zone.to_date, group[:available], group[:master_bl].created_at, group[:master_bl].id ] }
  end

  def available_quantity(item)
    item.quantity - @reserved.fetch(item.id, 0) - @loaded.fetch(item.id, 0)
  end
  helper_method :available_quantity

  def load_trip
    @trip = policy_scope(CargoDispatchTrip).find(params[:id])
  end

  def trip_params
    permitted = params.require(:cargo_dispatch_trip).permit(:origin_type, :transport_mode, :transport_name, :carrier_id)
    return permitted if current_user.admin?

    permitted.slice(:origin_type, :transport_mode, :transport_name)
  end

  def pass_params
    params.require(:cargo_dispatch_pass).permit(:operator_name, :plate, :economic_number, :unit_type)
  end
end
