class CreateCarriers < ActiveRecord::Migration[8.1]
  def change
    create_table :carriers do |t|
      t.string :name, null: false
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end

    add_index :carriers, :name
  end
end
