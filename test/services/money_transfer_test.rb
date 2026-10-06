require "test_helper"

class MoneyTransferTest < ActiveSupport::TestCase
  SimulatedFailure = Class.new(StandardError)

  setup do
    @alice = Account.create!(owner_name: "Alice", balance_cents: 10_000)
    @bob = Account.create!(owner_name: "Bob", balance_cents: 2_000)
  end

  test "moves money and records a transaction on each account" do
    assert_difference "Transaction.count", 2 do
      MoneyTransfer.new(sender: @alice, recipient: @bob, amount_cents: 2_500).call
    end

    assert_equal 7_500, @alice.reload.balance_cents
    assert_equal 4_500, @bob.reload.balance_cents

    debit = @alice.transactions.last
    assert_equal(-2_500, debit.amount_cents)
    assert_equal "Transfer to Bob", debit.description

    credit = @bob.transactions.last
    assert_equal 2_500, credit.amount_cents
    assert_equal "Transfer from Alice", credit.description
  end

  test "rolls back the debit when the transfer fails part-way" do
    alice_id = @alice.id
    alice_balance_during_transfer = nil

    # Fail the recipient's update, which runs right after the sender's debit.
    # A block (unlike `def`) can read and assign the surrounding local variables.
    @bob.define_singleton_method(:update!) do |*|
      alice_balance_during_transfer = Account.find(alice_id).balance_cents
      raise SimulatedFailure
    end

    assert_no_difference "Transaction.count" do
      assert_raises SimulatedFailure do
        MoneyTransfer.new(sender: @alice, recipient: @bob, amount_cents: 2_500).call
      end
    end

    assert_equal 7_500, alice_balance_during_transfer
    assert_equal 10_000, @alice.reload.balance_cents
    assert_equal 2_000, @bob.reload.balance_cents
  end

  test "rejects an amount that is not positive" do
    [ 0, -100 ].each do |amount_cents|
      assert_no_difference "Transaction.count" do
        assert_raises MoneyTransfer::InvalidAmount do
          MoneyTransfer.new(sender: @alice, recipient: @bob, amount_cents: amount_cents).call
        end
      end
    end

    assert_equal 10_000, @alice.reload.balance_cents
    assert_equal 2_000, @bob.reload.balance_cents
  end

  test "rejects a transfer larger than the sender's balance" do
    assert_no_difference "Transaction.count" do
      assert_raises MoneyTransfer::InsufficientFunds do
        MoneyTransfer.new(sender: @alice, recipient: @bob, amount_cents: 10_001).call
      end
    end

    assert_equal 10_000, @alice.reload.balance_cents
    assert_equal 2_000, @bob.reload.balance_cents
  end

  test "rejects a transfer to the same account" do
    assert_no_difference "Transaction.count" do
      assert_raises MoneyTransfer::SameAccount do
        MoneyTransfer.new(sender: @alice, recipient: Account.find(@alice.id), amount_cents: 100).call
      end
    end

    assert_equal 10_000, @alice.reload.balance_cents
  end
end
