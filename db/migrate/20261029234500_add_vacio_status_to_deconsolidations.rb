class AddVacioStatusToDeconsolidations < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :deconsolidations, name: "deconsolidations_status_valid"
    add_check_constraint :deconsolidations,
      "status IN ('apertura', 'desconsolidando', 'vacio', 'vaciado')", name: "deconsolidations_status_valid"
  end

  def down
    execute "UPDATE deconsolidations SET status = 'desconsolidando' WHERE status = 'vacio'"
    remove_check_constraint :deconsolidations, name: "deconsolidations_status_valid"
    add_check_constraint :deconsolidations,
      "status IN ('apertura', 'desconsolidando', 'vaciado')", name: "deconsolidations_status_valid"
  end
end
