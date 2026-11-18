class CargoDispatchPassPolicy < ApplicationPolicy
  def show? = CargoDispatchTripPolicy.new(user, record.cargo_dispatch_trip).show?
  def cancel? = record.active? && record.entered_at.nil? &&
    CargoDispatchTripPolicy.new(user, record.cargo_dispatch_trip).issue_pass?
end
