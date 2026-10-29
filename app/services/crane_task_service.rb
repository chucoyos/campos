class CraneTaskService
  class Error < StandardError
    def initialize(key)
      super(I18n.t("crane.errors.#{key}"))
    end
  end

  def self.complete(work_order:, user:)
    new(work_order, user).complete
  end

  def initialize(work_order, user)
    @work_order = work_order
    @user = user
  end

  def complete
    WorkOrder.transaction do
      @work_order = WorkOrder.lock.find(@work_order.id)
      raise Error, :not_pending unless @work_order.pendiente?

      @container = Container.lock.find(@work_order.container_id)
      @pass = @work_order.movement_pass
      slot = @work_order.to_yard_slot
      raise Error, :already_in_yard if @container.current_yard_slot_id.present?

      validate_destination(slot)
      @container.current_yard_slot = slot
      @container.declare_load_status!(@pass.load_status) if standalone_load_status?
      @container.llenar! if @container.may_llenar?
      @container.save!
      create_movement(slot)

      @work_order.completed_by = @user
      @work_order.completed_at = Time.current
      @work_order.completar!
      @work_order
    end
  end

  private

  def standalone_load_status?
    !@container.with_master_bl? && @pass&.load_status.present?
  end

  def validate_destination(slot)
    footprint = GateMovementService.footprint_for(@container, slot)
    raise Error, :destination_unavailable unless footprint

    YardSlot.where(yard_block_id: slot.yard_block_id).order(:id).lock.pluck(:id)
    occupied = GateMovementService.occupied_positions(slot.yard_block_id)
    raise Error, :destination_occupied if footprint.any? { |position| occupied.include?(position) }
    raise Error, :destination_unsupported unless GateMovementService.supported_footprint?(footprint, occupied)
  end

  def create_movement(slot)
    movement = ContainerMovement.create!(
      container: @container,
      movement_pass: @pass,
      from_yard_slot: nil,
      to_yard_slot: slot,
      user: @user,
      movement_type: @work_order.movement_type,
      load_status: @pass.load_status,
      created_at: Time.current
    )
    @pass.photos.blobs.each do |blob|
      ActiveStorage::Attachment.create!(name: "photos", record: movement, blob:)
    end
    @pass.photos.detach if @pass.photos.attached?
    movement
  end
end
