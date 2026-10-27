class HomeController < ApplicationController
  # Cada perfil aterriza en su primer módulo disponible; la bienvenida queda para cuentas sin módulos.
  def index
    destination = landing_path
    redirect_to destination if destination
  end

  private

  def landing_path
    if policy(MasterBl).index? then master_bls_path
    elsif policy(MovementPass).gate? then gate_path
    elsif policy(YardSlot).index? then yard_path
    elsif policy(ContainerAssignment).index? then container_assignments_path
    elsif policy(MovementPass).index? then movement_passes_path
    end
  end
end
