class CreateMasterBls < ActiveRecord::Migration[8.1]
  def change
    create_table :master_bls do |t|
      t.string :number, null: false
      t.references :client, null: false, foreign_key: true

      t.timestamps
    end

    add_index :master_bls, :number, unique: true
  end
end
