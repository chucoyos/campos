class ContainerAssignmentsController < ApplicationController
  def index
    authorize ContainerAssignment
    scope = policy_scope(ContainerAssignment).includes(:carrier, container: :master_bl)
    scope = scope.includes(:yard_area, :yard_area_section, container: { master_bl: :client }) if policy(ContainerAssignment).view_internal_details?
    @pagy, @assignments = paginate(apply_filters(scope.joins(container: :master_bl)).order("master_bls.number", "containers.number", :id))
    @active_passes = MovementPass.active.where(container_assignment_id: @assignments.map(&:id)).index_by(&:container_assignment_id)
  end

  def new
    @assignment = ContainerAssignment.new(operation: params[:operation].presence_in(ContainerAssignment::OPERATIONS) || "ingreso")
    authorize @assignment
    load_form_data
  end

  def create
    authorize ContainerAssignment
    @assignment = ContainerAssignment.new(assignment_params)
    ids = Array(params[:container_ids]).compact_blank
    @created = build_assignments(ids)

    if ids.any? && @created.all?(&:valid?) && save_all(@created)
      redirect_to container_assignments_path, notice: t("flash.container_assignments.create", count: @created.size)
    else
      @assignment.errors.add(:container, :blank) if ids.empty?
      @errors = @created.flat_map { |item| item.errors.full_messages.map { |message| "#{item.container.number}: #{message}" } }
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def cancel
    assignment = ContainerAssignment.find(params[:id])
    authorize assignment

    if assignment.with_lock { assignment.cancelar! if assignment.may_cancelar? }
      redirect_to container_assignments_path, notice: t("flash.container_assignments.cancel")
    else
      redirect_to container_assignments_path, alert: t("flash.container_assignments.not_cancelable")
    end
  end

  private

  def build_assignments(ids)
    Container.where(id: ids).includes(:master_bl).map do |container|
      ContainerAssignment.new(assignment_params.merge(container: container, assigned_by: current_user))
    end
  end

  def save_all(assignments)
    ContainerAssignment.transaction { assignments.each(&:save!) }
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def load_form_data
    @master_bls = MasterBl.includes(:client).order(:number)
    @master_bl = @master_bls.find_by(id: params[:master_bl_id])
    @containers = @master_bl ? @master_bl.containers.where.not(status: "entregado").order(:number) : Container.none
    @carriers = Carrier.order(:name)
    @areas = @master_bl ? YardArea.active.where(client_id: @master_bl.client_id).includes(:client, :sections).order(:code) : YardArea.none
    @selected_ids = Array(params[:container_ids]).map(&:to_i)
  end

  # "area:ID" o "section:ID" desde el selector de destino preferido.
  def assignment_params
    permitted = params.expect(container_assignment: %i[carrier_id operation destination preferred_level])
    kind, id = permitted.delete(:destination).to_s.split(":")
    case kind
    when "section"
      section = YardAreaSection.find_by(id: id)
      permitted.merge(yard_area_section: section, yard_area: section&.yard_area)
    when "area" then permitted.merge(yard_area_id: id)
    else permitted
    end
  end

  def filter_fields
    [
      { name: "q", type: :text, label: t("container_assignments.index.search"),
        apply: ->(scope, value) { scope.where("containers.number ILIKE :q OR master_bls.number ILIKE :q", q: like(value)) } },
      { name: "operation", type: :select, label: ContainerAssignment.human_attribute_name(:operation),
        options: ContainerAssignment::OPERATIONS.map { |op| [ t("container_assignments.operations.#{op}"), op ] },
        apply: ->(scope, value) { scope.where(operation: value) } },
      { name: "status", type: :select, label: ContainerAssignment.human_attribute_name(:status),
        options: %w[pendiente utilizada cancelada].map { |st| [ t("container_assignments.statuses.#{st}"), st ] },
        apply: ->(scope, value) { scope.where(status: value) } }
    ]
  end
end
