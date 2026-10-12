class MoveClientAndCarrierLinksToUsers < ActiveRecord::Migration[8.1]
  def up
    add_reference :users, :client, foreign_key: true, index: true
    add_reference :users, :carrier, foreign_key: true, index: true

    execute "UPDATE users SET client_id = clients.id FROM clients WHERE clients.user_id = users.id"
    execute "UPDATE users SET carrier_id = carriers.id FROM carriers WHERE carriers.user_id = users.id"

    remove_reference :clients, :user, foreign_key: true, index: true
    remove_reference :carriers, :user, foreign_key: true, index: true
  end

  def down
    add_reference :clients, :user, foreign_key: true, index: true
    add_reference :carriers, :user, foreign_key: true, index: true

    execute "UPDATE clients SET user_id = (SELECT MIN(users.id) FROM users WHERE users.client_id = clients.id)"
    execute "UPDATE carriers SET user_id = (SELECT MIN(users.id) FROM users WHERE users.carrier_id = carriers.id)"

    remove_reference :users, :client, foreign_key: true, index: true
    remove_reference :users, :carrier, foreign_key: true, index: true
  end
end
