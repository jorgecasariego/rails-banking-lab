require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  test "must belong to an account" do
    transaction = Transaction.new(
      description: "Initial deposit",
      amount_cents: 10_000
    )

    assert_not transaction.valid?
    assert_includes transaction.errors[:account], "must exist"
  end

  test "description must be present" do
    account = Account.create!(owner_name: "Jorge", balance_cents: 10_000)

    transaction = Transaction.new(
      account: account,
      amount_cents: 10_000
    )

    assert_not transaction.valid?
  end

  test "amount must be present" do
    account = Account.create!(owner_name: "Jorge", balance_cents: 10_000)

    transaction = Transaction.new(
      account: account,
      description: "Initial deposit"
    )

    assert_not transaction.valid?
  end

  test "amount must not be zero" do
    account = Account.create!(owner_name: "Jorge", balance_cents: 10_000)

    transaction = Transaction.new(
      account: account,
      description: "Invalid transaction",
      amount_cents: 0
    )

    assert_not transaction.valid?
  end
end
