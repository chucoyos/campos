class AddClientToContainers < ActiveRecord::Migration[8.1]
  def change
    add_reference :containers, :client, null: true, foreign_key: true, index: true
  end
end
