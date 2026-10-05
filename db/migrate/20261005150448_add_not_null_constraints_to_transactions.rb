class AddNotNullConstraintsToTransactions < ActiveRecord::Migration[8.1]
  def change
    change_column_null :transactions, :description, false
    change_column_null :transactions, :amount_cents, false
  end
end
