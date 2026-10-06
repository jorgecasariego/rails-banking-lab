require "test_helper"

class ToolCallHandlerTest < ActiveSupport::TestCase
  setup do
    @alice = Account.create!(owner_name: "Alice", balance_cents: 10_000)
    @bob = Account.create!(owner_name: "Bob", balance_cents: 2_000)
    @handler = ToolCallHandler.new(current_account: @alice)
  end

  test "a valid transfer_money proposal stops at confirmation and moves no money" do
    result = assert_no_money_moved do
      propose("recipient_name" => "Bob", "amount_cents" => 2_500)
    end

    assert_equal :confirmation_required, result.status
    assert_equal(
      { sender_id: @alice.id, recipient_id: @bob.id, recipient_name: "Bob", amount_cents: 2_500 },
      result.data
    )
  end

  test "accepts amount_cents sent as a digit string" do
    result = propose("recipient_name" => "Bob", "amount_cents" => "2500")

    assert_equal :confirmation_required, result.status
    assert_equal 2_500, result.data[:amount_cents]
  end

  test "trims whitespace around the recipient name" do
    result = propose("recipient_name" => "  Bob\n", "amount_cents" => 100)

    assert_equal :confirmation_required, result.status
    assert_equal @bob.id, result.data[:recipient_id]
  end

  test "the sender comes from current_account" do
    result = ToolCallHandler.new(current_account: @bob).call(
      ToolCall.new(name: "transfer_money", arguments: { "recipient_name" => "Alice", "amount_cents" => 100 })
    )

    assert_equal :confirmation_required, result.status
    assert_equal @bob.id, result.data[:sender_id]
    assert_equal @alice.id, result.data[:recipient_id]
  end

  test "rejects a model-supplied recipient_id" do
    assert_rejected(/unexpected arguments: recipient_id/,
      "recipient_id" => @bob.id, "recipient_name" => "Bob", "amount_cents" => 100)
  end

  test "rejects a model-supplied sender_id" do
    assert_rejected(/unexpected arguments: sender_id/,
      "sender_id" => @bob.id, "recipient_name" => "Bob", "amount_cents" => 100)
  end

  test "rejects a model-supplied account_id" do
    assert_rejected(/unexpected arguments: account_id/,
      "account_id" => @bob.id, "recipient_name" => "Bob", "amount_cents" => 100)
  end

  test "rejects unknown keys" do
    assert_rejected(/unexpected arguments: memo/,
      "recipient_name" => "Bob", "amount_cents" => 100, "memo" => "hi")
  end

  test "rejects arguments that are not an object" do
    [ nil, "recipient_name=Bob", [] ].each do |arguments|
      assert_rejected(/arguments must be an object/, arguments)
    end
  end

  test "rejects missing, blank or non-string recipient names" do
    [ nil, "", "   ", "\n\t", 42, true, [ "Bob" ], { "name" => "Bob" } ].each do |recipient_name|
      assert_rejected(/recipient_name must be a non-blank string/,
        "recipient_name" => recipient_name, "amount_cents" => 100)
    end
    assert_rejected(/recipient_name must be a non-blank string/, "amount_cents" => 100)
  end

  test "matches the recipient name exactly" do
    [ "bob", "BOB", "Bo", "Bobby", "B%", "%" ].each do |recipient_name|
      assert_rejected(/recipient not found/, "recipient_name" => recipient_name, "amount_cents" => 100)
    end
  end

  test "rejects recipients that do not exist" do
    assert_rejected(/recipient not found/, "recipient_name" => "Zed", "amount_cents" => 100)
  end

  test "rejects a name shared by more than one account" do
    Account.create!(owner_name: "Carol", balance_cents: 0)
    Account.create!(owner_name: "Carol", balance_cents: 0)

    assert_rejected(/ambiguous recipient/, "recipient_name" => "Carol", "amount_cents" => 100)
  end

  test "rejects transfers to the current account" do
    [ "Alice", " Alice " ].each do |recipient_name|
      assert_rejected(/same account/, "recipient_name" => recipient_name, "amount_cents" => 100)
    end
  end

  test "rejects invalid amount_cents" do
    [ nil, "", 25.5, "25.00", "$25", "2500abc", "-100", true ].each do |amount_cents|
      assert_rejected(/amount_cents must be an integer/,
        "recipient_name" => "Bob", "amount_cents" => amount_cents)
    end
    [ 0, -100 ].each do |amount_cents|
      assert_rejected(/amount_cents must be positive/,
        "recipient_name" => "Bob", "amount_cents" => amount_cents)
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

  # Compares against balances at the start of the block, so it also works
  # after a test has created extra accounts.
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
