class CreateContainers < ActiveRecord::Migration[8.1]
  def change
    create_table :containers do |t|
      t.string :number, null: false
      t.integer :size, null: false
      t.string :container_type, null: false
      t.string :status, null: false
      t.references :master_bl, null: true, foreign_key: true

      t.timestamps
    end

    add_index :containers, :number
    add_index :containers, :status
  end
end
