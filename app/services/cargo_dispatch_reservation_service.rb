class CargoDispatchReservationService
  class Error < StandardError; end

  def self.call(trip:, selections:)
    new(trip:, selections:).call
  end

  def initialize(trip:, selections:)
    @trip = trip
    @selections = selections
  end

  def call
    CargoDispatchTrip.transaction do
      trip = CargoDispatchTrip.lock.find(@trip.id)
      raise Error, I18n.t("cargo_dispatch.errors.trip_not_pending") unless trip.pending?
      raise Error, I18n.t("cargo_dispatch.errors.empty_selection") if @selections.empty?

      item_ids = @selections.map { |selection| selection.fetch(:cargo_item_id).to_i }
      instruction_ids = @selections.map { |selection| selection.fetch(:instruction_id).to_i }
      pairs = item_ids.zip(instruction_ids)
      raise Error, I18n.t("cargo_dispatch.errors.duplicate_selection") if pairs.uniq.size != pairs.size
      existing_pairs = trip.allocations.where(cargo_item_id: item_ids, cargo_dispatch_instruction_id: instruction_ids)
        .pluck(:cargo_item_id, :cargo_dispatch_instruction_id)
      raise Error, I18n.t("cargo_dispatch.errors.duplicate_selection") if (pairs & existing_pairs).any?

      instructions = trip.cargo_dispatch_request.instructions.where(id: instruction_ids).order(:id).lock.index_by(&:id)
      manifest_ids = CargoItem.where(id: item_ids).distinct.pluck(:cargo_manifest_id)
      CargoManifest.where(id: manifest_ids).order(:id).lock.load
      items = CargoItem.where(id: item_ids).order(:id).lock.index_by(&:id)
      raise Error, I18n.t("cargo_dispatch.errors.invalid_item") unless items.size == item_ids.uniq.size

      reserved = CargoDispatchAllocation.where(cargo_item_id: item_ids, status: "reserved").group(:cargo_item_id).sum(:reserved_quantity)
      loaded = CargoDispatchAllocation.where(cargo_item_id: item_ids, status: "confirmed").group(:cargo_item_id).sum(:loaded_quantity)
      instruction_reserved = CargoDispatchAllocation.where(cargo_dispatch_instruction_id: instruction_ids, status: "reserved")
        .group(:cargo_dispatch_instruction_id).sum(:reserved_quantity)
      instruction_loaded = CargoDispatchAllocation.where(cargo_dispatch_instruction_id: instruction_ids, status: "confirmed")
        .group(:cargo_dispatch_instruction_id).sum(:loaded_quantity)

      @selections.each do |selection|
        item = items.fetch(selection.fetch(:cargo_item_id).to_i)
        instruction = instructions[selection.fetch(:instruction_id).to_i]
        quantity = Integer(selection.fetch(:quantity), exception: false)
        validate_selection!(trip, instruction, item, quantity)

        available = item.quantity - reserved.fetch(item.id, 0) - loaded.fetch(item.id, 0)
        raise Error, I18n.t("cargo_dispatch.errors.insufficient_stock") if quantity > available
        if instruction.criterion == "quantity" &&
            quantity + instruction_reserved.fetch(instruction.id, 0) + instruction_loaded.fetch(instruction.id, 0) > instruction.quantity
          raise Error, I18n.t("cargo_dispatch.errors.request_exceeded")
        end

        trip.allocations.create!(cargo_dispatch_instruction: instruction, cargo_item: item, reserved_quantity: quantity)
        reserved[item.id] = reserved.fetch(item.id, 0) + quantity
        instruction_reserved[instruction.id] = instruction_reserved.fetch(instruction.id, 0) + quantity
      end
    end
  end

  private

  def validate_selection!(trip, instruction, item, quantity)
    raise Error, I18n.t("cargo_dispatch.errors.invalid_quantity") unless quantity&.positive?
    raise Error, I18n.t("cargo_dispatch.errors.invalid_instruction") unless instruction

    manifest = item.cargo_manifest
    valid_origin = trip.origin_type == (manifest.container_id ? "mbl" : "general")
    valid_client = manifest.client_id == trip.cargo_dispatch_request.client_id
    valid_container = !instruction.criterion.in?(%w[all half]) || instruction.container_id == manifest.container_id
    valid_packaging = instruction.cargo_packaging_id.nil? || instruction.cargo_packaging_id == item.cargo_packaging_id
    valid_weight = instruction.criterion != "weight" || item.weight_kg.present?
    unless valid_origin && valid_client && valid_container && valid_packaging && valid_weight && manifest.confirmed? && item.stored?
      raise Error, I18n.t("cargo_dispatch.errors.invalid_item")
    end
  end
end
