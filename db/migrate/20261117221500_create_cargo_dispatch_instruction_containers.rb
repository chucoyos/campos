class CreateCargoDispatchInstructionContainers < ActiveRecord::Migration[8.1]
  def change
    create_table :cargo_dispatch_instruction_containers do |t|
      t.references :cargo_dispatch_instruction, null: false, index: false, foreign_key: true
      t.references :container, null: false, foreign_key: true
      t.timestamps
    end

    add_index :cargo_dispatch_instruction_containers,
      [ :cargo_dispatch_instruction_id, :container_id ],
      unique: true,
      name: "index_dispatch_instruction_containers_on_instruction_container"
  end
end
