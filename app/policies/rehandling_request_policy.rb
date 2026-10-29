class RehandlingRequestPolicy < ApplicationPolicy
  def index? = operator?
  def show? = operator?
  def cancel? = user&.admin? && record.pendiente?

  class Scope < Scope
    def resolve
      user&.admin? || user&.grua? ? scope.all : scope.none
    end
  end

  private

  def operator? = user&.admin? || user&.grua?
end
