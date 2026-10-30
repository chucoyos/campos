class DeconsolidationService
  class Error < StandardError
    def initialize(key, container: nil)
      super(I18n.t("deconsolidations.errors.#{key}", container: container&.number))
    end
  end

  Result = Struct.new(:deconsolidation, :rehandle_order, keyword_init: true)

  # Se invoca al llegar un contenedor a DESYCON; no hace nada si no aplica.
  def self.start_if_desycon(container, user)
    return unless container.with_master_bl? && container.current_yard_slot&.desycon?
    return if Deconsolidation.exists?(container_id: container.id)

    Deconsolidation.create!(container:, created_by: user)
  end

  def self.start(container:, user:)
    container = Container.lock.find(container.id)
    raise Error.new(:not_with_master_bl, container:) unless container.with_master_bl?
    raise Error.new(:not_in_desycon, container:) unless container.current_yard_slot&.desycon?
    raise Error.new(:already_started, container:) if Deconsolidation.exists?(container_id: container.id)

    Deconsolidation.create!(container:, created_by: user)
  end

  def self.advance(deconsolidation:, user:)
    new(user).advance(deconsolidation)
  end

  def initialize(user)
    @user = user
  end

  def advance(deconsolidation)
    Deconsolidation.transaction do
      deconsolidation = Deconsolidation.lock.find(deconsolidation.id)
      container = Container.lock.find(deconsolidation.container_id)

      case deconsolidation.status
      when "apertura" then start_deconsolidating(deconsolidation, container)
      when "desconsolidando" then start_empty_stage(deconsolidation, container)
      when "vacio" then finish(deconsolidation, container)
      else raise Error.new(:already_finished, container:)
      end
    end
  end

  private

  def start_deconsolidating(deconsolidation, container)
    raise Error.new(:opening_photos_missing, container:) unless deconsolidation.may_iniciar_desconsolidacion?

    deconsolidation.iniciar_desconsolidacion!
    Result.new(deconsolidation:)
  end

  def start_empty_stage(deconsolidation, container)
    raise Error.new(:deconsolidation_photos_missing, container:) unless deconsolidation.deconsolidation_photos_present?
    raise Error.new(:cargo_pending, container:) unless deconsolidation.may_registrar_vacio?

    deconsolidation.registrar_vacio!
    Result.new(deconsolidation:)
  end

  def finish(deconsolidation, container)
    raise Error.new(:empty_photos_missing, container:) unless deconsolidation.may_vaciar?

    deconsolidation.vaciar!
    container.vaciar! if container.may_vaciar?
    Result.new(deconsolidation:, rehandle_order: create_rehandle_order(container))
  end

  # La grúa recibe la tarea con una posición sugerida (sección del MBL o cliente) y puede cambiarla.
  def create_rehandle_order(container)
    origin = container.current_yard_slot
    return unless origin
    return if container.work_orders.where(status: "pendiente").exists? ||
      container.movement_plans.where(status: "pendiente").exists?

    destination = GateMovementService.available_slots(container).first
    return unless destination

    WorkOrder.create!(
      container:, movement_type: "reacomodo", from_yard_slot: origin, to_yard_slot: destination, created_by: @user
    )
  end
end
