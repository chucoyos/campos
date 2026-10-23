class CreateOperationalYardAreas < ActiveRecord::Migration[8.1]
  def change
    create_table :yard_areas do |t|
      t.references :yard_block, null: false, foreign_key: true
      t.references :client, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :yard_areas, :code, unique: true

    create_table :yard_area_sections do |t|
      t.references :yard_area, null: false, foreign_key: true
      t.references :master_bl, foreign_key: true
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :yard_area_sections, %i[yard_area_id name], unique: true

    add_reference :yard_slots, :yard_area_section, foreign_key: { on_delete: :nullify }, index: true
  end
end
