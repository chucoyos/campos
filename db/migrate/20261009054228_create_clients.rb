class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.string :name, null: false
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end

    add_index :clients, :name
  end
end
