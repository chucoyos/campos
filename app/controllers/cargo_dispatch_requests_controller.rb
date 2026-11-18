class CargoDispatchRequestsController < ApplicationController
  def index
    authorize CargoDispatchRequest
    @pagy, @requests = paginate(policy_scope(CargoDispatchRequest).includes(:client).order(created_at: :desc, id: :desc))
  end

  def new
    @request = CargoDispatchRequest.new
    authorize @request
    @request.client_id = current_user.client_id if current_user.client_member?
    load_options(client_id: params[:client_id])
  end

  def create
    @request = CargoDispatchRequest.new(destination: request_params[:destination], requested_by: current_user)
    @request.client_id = current_user.admin? ? request_params[:client_id] : current_user.client_id
    authorize @request
    instruction_attributes.each { |attributes| @request.instructions.build(attributes) }
    if @request.save
      redirect_to cargo_dispatch_request_path(@request), notice: t("cargo_dispatch.flash.request_created")
    else
      load_options(client_id: @request.client_id)
      render :new, status: :unprocessable_content
    end
  end

  def show
    @request = policy_scope(CargoDispatchRequest).find(params[:id])
    authorize @request
    instructions = @request.instructions
    @instructions = instructions.includes(:preferred_containers).order(:id)
    @instructions = @instructions.includes(:container) if instructions.where.not(container_id: nil).exists?
    @instructions = @instructions.includes(:cargo_packaging) if instructions.where(criterion: "quantity").exists?
    @allocated_instruction_ids = CargoDispatchAllocation.where(cargo_dispatch_instruction_id: instructions.select(:id))
      .distinct.pluck(:cargo_dispatch_instruction_id)
    @trips = @request.trips.order(:id)
    @containers = Container.joins(:master_bl).where(master_bls: { client_id: @request.client_id }).includes(:master_bl).order(:number)
    @packagings = CargoPackaging.active.order(:name)
    @carriers = Carrier.order(:name) if current_user.admin?
    load_availability(@request.client_id)
  end

  def add_instruction
    request_record = policy_scope(CargoDispatchRequest).find(params[:id])
    authorize request_record
    CargoDispatchInstruction.transaction do
      instruction_attributes.each { |attributes| request_record.instructions.create!(attributes) }
    end
    redirect_to cargo_dispatch_request_path(request_record), notice: t("cargo_dispatch.flash.instruction_added")
  rescue ActiveRecord::RecordInvalid => error
    redirect_to cargo_dispatch_request_path(request_record), alert: error.record.errors.full_messages.to_sentence
  end

  def remove_instruction
    request_record = policy_scope(CargoDispatchRequest).find(params[:id])
    authorize request_record
    instruction = request_record.instructions.find(params[:instruction_id])
    result = instruction.with_lock do
      if instruction.allocations.exists?
        :has_history
      else
        instruction.destroy ? :removed : :invalid
      end
    end
    case result
    when :removed
      redirect_to cargo_dispatch_request_path(request_record), notice: t("cargo_dispatch.flash.instruction_removed")
    when :has_history
      redirect_to cargo_dispatch_request_path(request_record), alert: t("cargo_dispatch.ui.instruction_has_history")
    when :invalid
      redirect_to cargo_dispatch_request_path(request_record), alert: instruction.errors.full_messages.to_sentence
    end
  end

  private

  def request_params
    params.require(:cargo_dispatch_request).permit(:client_id, :destination)
  end

  def instruction_params
    values = params.require(:instruction).permit(:criterion, :cargo_packaging_id, :quantity, :weight_kg, preferred_container_ids: [])
    case values[:criterion]
    when "quantity" then values.slice(:criterion, :cargo_packaging_id, :quantity, :preferred_container_ids)
    when "weight" then values.slice(:criterion, :weight_kg, :preferred_container_ids)
    else values.slice(:criterion, :preferred_container_ids)
    end
  end

  def instruction_attributes
    attributes = instruction_params.to_h
    preferred_container_ids = attributes.delete("preferred_container_ids")
    if preferred_container_ids.present?
      containers = Container.where(id: preferred_container_ids).includes(
        opening_photos_attachments: :blob,
        deconsolidation_photos_attachments: :blob,
        empty_photos_attachments: :blob
      ).to_a
      raise ActiveRecord::RecordNotFound unless containers.size == preferred_container_ids.uniq.size

      attributes["preferred_containers"] = containers
    end
    [ attributes ]
  end

  def load_options(client_id: nil)
    @clients = Client.order(:name) if current_user.admin?
    @selected_client_id = current_user.admin? ? client_id.presence : current_user.client_id
    @containers = policy_scope(Container).joins(:master_bl).includes(:master_bl).order(:number)
    @packagings = CargoPackaging.active.order(:name)
    load_availability(current_user.client_id) if current_user.client_member? && !current_user.admin?
  end

  def load_availability(client_id)
    totals = CargoDispatchAllocation.group(:cargo_item_id).select(
      "cargo_item_id, SUM(CASE WHEN status = 'reserved' THEN reserved_quantity ELSE 0 END) AS reserved, " \
      "SUM(CASE WHEN status = 'confirmed' THEN loaded_quantity ELSE 0 END) AS loaded"
    )
    available = "cargo_items.quantity - COALESCE(dispatch_totals.reserved, 0) - COALESCE(dispatch_totals.loaded, 0)"
    @availability = CargoItem.joins(:cargo_packaging, :cargo_manifest)
      .left_joins(cargo_manifest: { container: :master_bl })
      .joins("LEFT JOIN (#{totals.to_sql}) dispatch_totals ON dispatch_totals.cargo_item_id = cargo_items.id")
      .where(status: "stored", cargo_manifests: { client_id: client_id, status: "confirmed" })
      .group("containers.id", "containers.number", "master_bls.number", "master_bls.created_at",
        "cargo_packagings.id", "cargo_packagings.name")
      .having("SUM(#{available}) > 0")
      .select("containers.number AS container_number, master_bls.number AS master_bl_number, " \
        "cargo_packagings.name AS packaging_name, SUM(#{available})::bigint AS available_units, " \
        "SUM((#{available}) * cargo_items.weight_kg) AS known_weight, " \
        "SUM(CASE WHEN cargo_items.weight_kg IS NULL THEN #{available} ELSE 0 END)::bigint AS unknown_weight_units")
      .order(Arel.sql("master_bls.created_at ASC NULLS LAST, containers.number, cargo_packagings.name"))
  end
end
