class CargoItemPolicy < ApplicationPolicy
  def show? = CargoManifestPolicy.new(user, record.cargo_manifest).show?
  def create? = CargoManifestPolicy.new(user, record.cargo_manifest).update?
  def update? = create?
  def destroy? = create?
end
