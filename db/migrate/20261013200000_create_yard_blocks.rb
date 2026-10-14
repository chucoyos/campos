class CreateYardBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :yard_blocks do |t|
      t.string :code, null: false
      t.integer :bays, null: false
      t.integer :rows, null: false
      t.integer :levels, null: false
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :yard_blocks, :code, unique: true
    add_check_constraint :yard_blocks, "bays > 0 AND rows BETWEEN 1 AND 26 AND levels > 0", name: "yard_blocks_dimensions_positive"
  end
end
