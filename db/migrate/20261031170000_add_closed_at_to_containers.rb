class AddClosedAtToContainers < ActiveRecord::Migration[8.1]
  def up
    add_column :containers, :closed_at, :datetime

    # Un contenedor cuyo último movimiento fue una salida o un traspaleo ya terminó su ciclo.
    execute <<~SQL.squish
      UPDATE containers
      SET closed_at = last_exit.created_at
      FROM (
        SELECT DISTINCT ON (container_id) container_id, movement_type, created_at
        FROM container_movements
        ORDER BY container_id, id DESC
      ) AS last_exit
      WHERE last_exit.container_id = containers.id
        AND last_exit.movement_type IN ('salida', 'traspaleo')
        AND containers.current_yard_slot_id IS NULL
    SQL

    remove_index :containers, :number
    add_index :containers, :number, unique: true, where: "closed_at IS NULL", name: "index_containers_on_number_active"
  end

  def down
    remove_index :containers, name: "index_containers_on_number_active"
    add_index :containers, :number
    remove_column :containers, :closed_at
  end
end
