class CreateYardAreas < ActiveRecord::Migration[8.1]
  def change
    create_table :yard_areas do |t|
      t.string :code, null: false
      t.string :name, null: false
      # NULL significa capacidad desconocida, nunca ilimitada.
      t.integer :capacity
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :yard_areas, :code, unique: true
    add_check_constraint :yard_areas, "capacity IS NULL OR capacity > 0", name: "yard_areas_capacity_positive"
  end
end
