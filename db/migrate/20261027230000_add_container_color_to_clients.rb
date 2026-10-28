class AddContainerColorToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :container_color, :string
  end
end
