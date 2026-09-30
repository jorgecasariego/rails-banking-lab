require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "owner name is required" do
    account = Account.new(owner_name: nil)

    assert_not account.valid?
    assert_includes account.errors[:owner_name], "can't be blank"
  end

  test "cannot destroy an account with transactions" do
    account = Account.create!(owner_name: "Jorge", balance_cents: 10_000)

    account.transactions.create!(
      description: "Initial deposit",
      amount_cents: 10_000
    )

    assert_not account.destroy
    assert Account.exists?(account.id)
  end
end
