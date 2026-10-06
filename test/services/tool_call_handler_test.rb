require "test_helper"

class ToolCallHandlerTest < ActiveSupport::TestCase
  setup do
    @alice = Account.create!(owner_name: "Alice", balance_cents: 10_000)
    @bob = Account.create!(owner_name: "Bob", balance_cents: 2_000)
    @handler = ToolCallHandler.new(current_account: @alice)
  end

  test "a valid transfer_money proposal stops at confirmation and moves no money" do
    result = assert_no_money_moved do
      propose("recipient_id" => @bob.id, "amount_cents" => 2_500)
    end

    assert_equal :confirmation_required, result.status
    assert_equal(
      { sender_id: @alice.id, recipient_id: @bob.id, recipient_name: "Bob", amount_cents: 2_500 },
      result.data
    )
  end

  test "accepts integers sent as digit strings" do
    result = propose("recipient_id" => @bob.id.to_s, "amount_cents" => "2500")

    assert_equal :confirmation_required, result.status
    assert_equal 2_500, result.data[:amount_cents]
  end

  test "the sender comes from current_account" do
    result = ToolCallHandler.new(current_account: @bob).call(
      ToolCall.new(name: "transfer_money", arguments: { "recipient_id" => @alice.id, "amount_cents" => 100 })
    )

    assert_equal :confirmation_required, result.status
    assert_equal @bob.id, result.data[:sender_id]
  end

  test "rejects a model-supplied sender_id" do
    assert_rejected(/unexpected arguments: sender_id/,
      "sender_id" => @bob.id, "recipient_id" => @bob.id, "amount_cents" => 100)
  end

  test "rejects a model-supplied account_id" do
    assert_rejected(/unexpected arguments: account_id/,
      "account_id" => @bob.id, "recipient_id" => @bob.id, "amount_cents" => 100)
  end

  test "rejects unknown keys" do
    assert_rejected(/unexpected arguments: memo/,
      "recipient_id" => @bob.id, "amount_cents" => 100, "memo" => "hi")
  end

  test "rejects arguments that are not an object" do
    [ nil, "recipient_id=1", [] ].each do |arguments|
      assert_rejected(/arguments must be an object/, arguments)
    end
  end

  test "rejects missing or malformed recipient IDs" do
    [ nil, "", "abc", "1 OR 1=1", "-1", 1.0, true ].each do |recipient_id|
      assert_rejected(/recipient_id must be an integer/,
        "recipient_id" => recipient_id, "amount_cents" => 100)
    end
    assert_rejected(/recipient_id must be an integer/, "amount_cents" => 100)
  end

  test "rejects recipients that do not exist" do
    [ Account.maximum(:id) + 1, 2**64 ].each do |recipient_id|
      assert_rejected(/recipient not found/, "recipient_id" => recipient_id, "amount_cents" => 100)
    end
  end

  test "rejects transfers to the current account" do
    [ @alice.id, @alice.id.to_s ].each do |recipient_id|
      assert_rejected(/same account/, "recipient_id" => recipient_id, "amount_cents" => 100)
    end
  end

  test "rejects invalid amount_cents" do
    [ nil, "", 25.5, "25.00", "$25", "2500abc", "-100", true ].each do |amount_cents|
      assert_rejected(/amount_cents must be an integer/,
        "recipient_id" => @bob.id, "amount_cents" => amount_cents)
    end
    [ 0, -100 ].each do |amount_cents|
      assert_rejected(/amount_cents must be positive/,
        "recipient_id" => @bob.id, "amount_cents" => amount_cents)
    end
  end

  test "denies unknown tools" do
    result = assert_no_money_moved do
      @handler.call(ToolCall.new(name: "delete_account", arguments: {}))
    end

    assert_equal :rejected, result.status
    assert_match(/tool not allowed/, result.error)
  end

  private

  def propose(arguments)
    @handler.call(ToolCall.new(name: "transfer_money", arguments: arguments))
  end

  def assert_rejected(error_pattern, arguments)
    result = assert_no_money_moved { propose(arguments) }

    assert_equal :rejected, result.status, "expected #{arguments.inspect} to be rejected"
    assert_match error_pattern, result.error
  end

  def assert_no_money_moved
    result = nil
    assert_no_difference "Transaction.count" do
      result = yield
    end
    assert_equal 10_000, @alice.reload.balance_cents
    assert_equal 2_000, @bob.reload.balance_cents
    result
  end
end
