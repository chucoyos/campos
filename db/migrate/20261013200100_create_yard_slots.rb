class CreateYardSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :yard_slots do |t|
      t.references :yard_block, null: false, foreign_key: true
      t.integer :bay, null: false
      t.string :row, null: false, limit: 1
      t.integer :level, null: false
      t.string :code, null: false
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :yard_slots, :code, unique: true
    add_index :yard_slots, %i[yard_block_id bay row level], unique: true, name: "index_yard_slots_on_position"
    add_check_constraint :yard_slots, "bay > 0 AND level > 0 AND row ~ '^[A-Z]$'", name: "yard_slots_position_valid"
  end
end
