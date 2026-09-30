class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.string :description, null: false
      t.integer :amount_cents, null: false

      t.timestamps
    end
  end
end
