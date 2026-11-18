class CargoDispatchOperationService
  class Error < StandardError; end

  def self.report!(trip:, allocation:, quantity:, user:)
    CargoDispatchTrip.transaction do
      trip = CargoDispatchTrip.lock.find(trip.id)
      raise Error, I18n.t("cargo_dispatch.errors.not_in_yard") unless trip.in_yard?

      allocation = trip.allocations.lock.find(allocation.id)
      quantity = Integer(quantity, exception: false)
      unless allocation.status == "reserved" && quantity && quantity.between?(0, allocation.reserved_quantity)
        raise Error, I18n.t("cargo_dispatch.errors.invalid_report")
      end

      allocation.update!(reported_quantity: quantity, reported_by: user, reported_at: Time.current)
      trip.events.create!(user: user, event: "reported", details: "#{allocation.id}: #{quantity}")
      trip.touch
    end
  end

  def self.confirm!(trip:, user:, reason: nil)
    CargoDispatchTrip.transaction do
      trip = CargoDispatchTrip.lock.find(trip.id)
      raise Error, I18n.t("cargo_dispatch.errors.not_in_yard") unless trip.in_yard?

      allocations = trip.allocations.where(status: "reserved").order(:id).lock.to_a
      raise Error, I18n.t("cargo_dispatch.errors.empty_selection") if allocations.empty?
      raise Error, I18n.t("cargo_dispatch.errors.reason_required") if allocations.sum(&:reported_quantity).zero? && reason.blank?

      item_ids = allocations.map(&:cargo_item_id).uniq.sort
      items = CargoItem.where(id: item_ids).order(:id).lock.index_by(&:id)
      prior = CargoDispatchAllocation.where(cargo_item_id: item_ids, status: "confirmed").group(:cargo_item_id).sum(:loaded_quantity)
      reported = allocations.group_by(&:cargo_item_id).transform_values { |rows| rows.sum(&:reported_quantity) }

      items.each_value do |item|
        unless item.stored? && item.cargo_manifest.confirmed? && prior.fetch(item.id, 0) + reported.fetch(item.id) <= item.quantity
          raise Error, I18n.t("cargo_dispatch.errors.invalid_item")
        end
      end

      allocations.each do |allocation|
        item = items.fetch(allocation.cargo_item_id)
        allocation.assign_attributes(loaded_quantity: allocation.reported_quantity, confirmed_by: user, confirmed_at: Time.current,
          warehouse_slot: item.warehouse_slot, slot_section: item.slot_section)
        allocation.reported_quantity.positive? ? allocation.confirm_loading! : allocation.release!
      end
      items.each_value do |item|
        next unless prior.fetch(item.id, 0) + reported.fetch(item.id) == item.quantity

        item.assign_attributes(warehouse_slot: nil, slot_section: nil)
        item.dispatch!
      end
      trip.confirm_loading!
      trip.events.create!(user: user, event: "loading_confirmed", details: reason.presence)
    end
  end

  def self.enter!(pass:, user:)
    CargoDispatchTrip.transaction do
      trip = CargoDispatchTrip.lock.find(pass.cargo_dispatch_trip_id)
      pass = trip.passes.lock.find(pass.id)
      raise Error, I18n.t("cargo_dispatch.errors.pass_unusable") unless pass.usable?
      return if pass.entered_at?
      raise Error, I18n.t("cargo_dispatch.errors.trip_not_prepared") unless trip.prepared?

      pass.update!(entered_at: Time.current)
      trip.arrive!
      trip.events.create!(user: user, cargo_dispatch_pass: pass, event: "entered")
    end
  end

  def self.cancel!(trip:, user:)
    CargoDispatchTrip.transaction do
      trip = CargoDispatchTrip.lock.find(trip.id)
      raise Error, I18n.t("cargo_dispatch.errors.cannot_cancel") unless trip.may_cancel?

      pass = trip.passes.where(status: "active").lock.first
      pass.cancel! if pass
      trip.allocations.where(status: "reserved").order(:id).lock.each(&:release!)
      trip.cancel!
      trip.events.create!(user: user, cargo_dispatch_pass: pass, event: "trip_cancelled")
    end
  end

  def self.exit!(pass:, user:)
    CargoDispatchTrip.transaction do
      trip = CargoDispatchTrip.lock.find(pass.cargo_dispatch_trip_id)
      pass = trip.passes.lock.find(pass.id)
      return if pass.completed?
      raise Error, I18n.t("cargo_dispatch.errors.pass_unusable") unless pass.usable? && pass.entered_at?
      raise Error, I18n.t("cargo_dispatch.errors.loading_unconfirmed") unless trip.loaded?
      raise Error, I18n.t("cargo_dispatch.errors.exit_scan_required") unless pass.exit_scanned_at?

      trip.finish!
      pass.complete!
      trip.events.create!(user: user, cargo_dispatch_pass: pass, event: "exited")
    end
  end
end
