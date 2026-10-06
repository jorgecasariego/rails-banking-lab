require "test_helper"

class ToolCallConfirmationTest < ActiveSupport::TestCase
  setup do
    @alice = Account.create!(owner_name: "Alice", balance_cents: 10_000)
    @bob = Account.create!(owner_name: "Bob", balance_cents: 2_000)
    @transfer = ToolCall.new(name: "transfer_money", arguments: { "recipient_name" => "Bob", "amount_cents" => 2_500 })
  end

  test "a proposal moves nothing until it is confirmed" do
    proposal = assert_no_money_moved do
      ToolCallHandler.new(current_account: @alice).call(@transfer)
    end
    assert_equal :confirmation_required, proposal.status

    result = assert_difference "Transaction.count", 2 do
      ToolCallConfirmation.new(current_account: @alice).call(@transfer)
    end

    assert_equal :executed, result.status
    assert_equal 7_500, @alice.reload.balance_cents
    assert_equal 4_500, @bob.reload.balance_cents
  end

  test "the sender comes from current_account" do
    carol = Account.create!(owner_name: "Carol", balance_cents: 0)
    tool_call = ToolCall.new(name: "transfer_money", arguments: { "recipient_name" => "Carol", "amount_cents" => 500 })

    result = ToolCallConfirmation.new(current_account: @bob).call(tool_call)

    assert_equal :executed, result.status
    assert_equal 10_000, @alice.reload.balance_cents
    assert_equal 1_500, @bob.reload.balance_cents
    assert_equal 500, carol.reload.balance_cents
  end

  test "validates arguments again on confirmation" do
    tool_call = ToolCall.new(name: "transfer_money",
      arguments: { "sender_id" => @bob.id, "recipient_name" => "Bob", "amount_cents" => 100 })

    result = assert_no_money_moved { confirm(tool_call) }

    assert_equal :rejected, result.status
    assert_match(/unexpected arguments: sender_id/, result.error)
  end

  test "rejects a recipient deleted between proposal and confirmation" do
    carol = Account.create!(owner_name: "Carol", balance_cents: 0)
    tool_call = ToolCall.new(name: "transfer_money", arguments: { "recipient_name" => "Carol", "amount_cents" => 100 })
    assert_equal :confirmation_required, ToolCallHandler.new(current_account: @alice).call(tool_call).status

    carol.destroy!
    result = assert_no_money_moved { confirm(tool_call) }

    assert_equal :rejected, result.status
    assert_match(/recipient not found/, result.error)
  end

  test "rejects a name that became ambiguous between proposal and confirmation" do
    assert_equal :confirmation_required, ToolCallHandler.new(current_account: @alice).call(@transfer).status

    Account.create!(owner_name: "Bob", balance_cents: 0)
    result = assert_no_money_moved { confirm(@transfer) }

    assert_equal :rejected, result.status
    assert_match(/ambiguous recipient/, result.error)
  end

  test "rejects when the balance drops between proposal and confirmation" do
    tool_call = ToolCall.new(name: "transfer_money", arguments: { "recipient_name" => "Bob", "amount_cents" => 8_000 })
    assert_equal :confirmation_required, ToolCallHandler.new(current_account: @alice).call(tool_call).status

    # Another transfer lands first. @alice in memory still says 10_000.
    MoneyTransfer.new(sender: Account.find(@alice.id), recipient: @bob, amount_cents: 5_000).call

    result = assert_no_money_moved { confirm(tool_call) }

    assert_equal :rejected, result.status
    assert_match(/insufficient balance/, result.error)
    assert_equal 5_000, @alice.reload.balance_cents
    assert_equal 7_000, @bob.reload.balance_cents
  end

  test "only tools whose policy is :confirm may be confirmed" do
    [ "delete_account", "get_account_balance", nil ].each do |name|
      result = assert_no_money_moved do
        confirm(ToolCall.new(name: name, arguments: { "recipient_name" => "Bob", "amount_cents" => 100 }))
      end

      assert_equal :rejected, result.status
      assert_match(/does not accept confirmation/, result.error)
    end
  end

  private

  def confirm(tool_call)
    ToolCallConfirmation.new(current_account: @alice).call(tool_call)
  end

  # Compares against balances at the start of the block, so it also works
  # after a test has changed balances during setup.
  def assert_no_money_moved
    balances = Account.order(:id).pluck(:id, :balance_cents)
    result = nil
    assert_no_difference "Transaction.count" do
      result = yield
    end
    assert_equal balances, Account.order(:id).pluck(:id, :balance_cents)
    result
  end
end
