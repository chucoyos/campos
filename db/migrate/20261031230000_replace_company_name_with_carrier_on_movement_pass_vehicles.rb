class ReplaceCompanyNameWithCarrierOnMovementPassVehicles < ActiveRecord::Migration[8.1]
  def up
    # Los datos existentes son de prueba; no se migran nombres de empresa a transportistas.
    execute "DELETE FROM movement_pass_vehicles"
    remove_column :movement_pass_vehicles, :company_name
    add_reference :movement_pass_vehicles, :carrier, null: false, foreign_key: true
    add_column :movement_pass_vehicles, :economic_number, :string
  end

  def down
    remove_column :movement_pass_vehicles, :economic_number
    remove_reference :movement_pass_vehicles, :carrier, foreign_key: true
    add_column :movement_pass_vehicles, :company_name, :string, null: false, default: ""
    change_column_default :movement_pass_vehicles, :company_name, from: "", to: nil
  end
end
