class MovementPassesController < ApplicationController
  def index
    authorize MovementPass
    scope = policy_scope(MovementPass).includes(:vehicles, container: :master_bl).order(issued_at: :desc)
    scope = scope.includes(:client) if current_user.admin? || current_user.seguridad? || current_user.client_member?
    @pagy, @passes = paginate(apply_filters(scope.joins(:container)))
  end

  def new
    authorize MovementPass
    if params[:assignment_id].present? || params[:container_id].present?
      @pass = build_pass
      authorize @pass, :create?
    else
      load_options
    end
  end

  def create
    @pass = build_pass(pass_params)
    authorize @pass

    if @pass.save
      redirect_to movement_pass_path(@pass), notice: t("flash.movement_passes.create")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @pass = MovementPass.find(params[:id])
    authorize @pass
    @pass.with_lock { @pass.vencer! if @pass.may_vencer? }
    @gate_url = gate_pass_url(@pass.token) if @pass.usable?

    respond_to do |format|
      format.html
      format.pdf { send_pdf }
    end
  end

  def cancel
    pass = MovementPass.find(params[:id])
    authorize pass

    cancelled = pass.with_lock do
      pass.cancelar! if pass.may_cancelar?
    end
    if cancelled
      redirect_to movement_pass_path(pass), notice: t("flash.movement_passes.cancel")
    else
      redirect_to movement_pass_path(pass), alert: t("flash.movement_passes.not_cancelable")
    end
  end

  private

  def send_pdf
    return redirect_to(movement_pass_path(@pass), alert: t("flash.movement_passes.not_downloadable")) unless @pass.usable?

    send_data MovementPassPdf.new(@pass, gate_url: @gate_url).render, filename: "pase-#{@pass.container.number}-#{@pass.movement_type}.pdf",
                                                  type: "application/pdf", disposition: "inline"
  end

  def build_pass(attributes = {})
    assignment = ContainerAssignment.find_by(id: params[:assignment_id]) if params[:assignment_id].present?
    container = assignment&.container || Container.find(params[:container_id])
    type = assignment&.operation || params[:movement_type]
    pass = MovementPass.new(attributes.merge(container: container, container_assignment: assignment, movement_type: type, requested_by: current_user))
    prepare_vehicles(pass, assignment)
    pass
  end

  # Un formulario por rol de vehículo; el traspaleo exige un segundo camión.
  def prepare_vehicles(pass, assignment)
    roles = pass.movement_type == "traspaleo" ? MovementPassVehicle::ROLES : %w[principal]
    default_company = assignment&.carrier&.name || current_user.carrier&.name
    roles.each do |role|
      next if pass.vehicle(role)

      pass.vehicles.build(role: role, company_name: role == "principal" ? default_company : nil)
    end
  end

  def pass_params
    params.fetch(:movement_pass, {}).permit(:load_status, vehicles_attributes: %i[role company_name operator_name plate unit_type])
  end

  def load_options
    @assignments = policy_scope(ContainerAssignment).pendiente.includes(:carrier, container: :master_bl)
                     .where.not(id: MovementPass.active.where.not(container_assignment_id: nil).select(:container_assignment_id)).order(:id)
    @assignments = @assignments.includes(container: { master_bl: :client }) if current_user.admin?
    @assignments = @assignments.none unless current_user.admin? || current_user.carrier_member?
    @containers = standalone_containers.includes(:client).order(:number)
  end

  def standalone_containers
    return Container.where(master_bl_id: nil) if current_user.admin?
    return Container.none unless current_user.client_member?

    Container.where(master_bl_id: nil, client_id: current_user.client_id)
  end

  def filter_fields
    [
      { name: "q", type: :text, label: t("movement_passes.index.search"),
        apply: ->(scope, value) { scope.where("containers.number ILIKE ?", like(value)) } },
      { name: "movement_type", type: :select, label: MovementPass.human_attribute_name(:movement_type),
        options: MovementPass::MOVEMENT_TYPES.map { |type| [ t("movement_passes.types.#{type}"), type ] },
        apply: ->(scope, value) { scope.where(movement_type: value) } },
      { name: "status", type: :select, label: MovementPass.human_attribute_name(:status),
        options: %w[vigente completado cancelado vencido].map { |status| [ t("movement_passes.statuses.#{status}"), status ] },
        apply: ->(scope, value) { scope.where(status: value) } }
    ]
  end
end
