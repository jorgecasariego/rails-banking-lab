class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :owner_name, null: false
      t.integer :balance_cents, null: false, default: 0

      t.timestamps
    end
  end
end
