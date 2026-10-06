require "test_helper"

# Offline: every test injects send_request, so no request reaches the API.
class ToolCallProposerTest < ActiveSupport::TestCase
  setup do
    @alice = Account.create!(owner_name: "Alice", balance_cents: 10_000)
    @bob = Account.create!(owner_name: "Bob", balance_cents: 2_000)
  end

  test "sends exactly one strict transfer_money tool to claude-haiku-4-5" do
    params = capture_request("Send $10 to Alice")

    assert_equal "claude-haiku-4-5", params[:model]
    assert_equal [ "transfer_money" ], params[:tools].map { _1[:name] }

    tool = params[:tools].first
    assert_equal true, tool[:strict]
    assert_equal %i[recipient_name amount_cents], tool[:input_schema][:properties].keys
    assert_equal %w[recipient_name amount_cents], tool[:input_schema][:required]
    assert_equal false, tool[:input_schema][:additionalProperties]
    assert_equal({ type: "auto", disable_parallel_tool_use: true }, params[:tool_choice])
  end

  test "sends only the instruction, with no application or database context" do
    params = capture_request("Send $10 to Alice")

    assert_equal [ { role: "user", content: "Send $10 to Alice" } ], params[:messages]

    serialized = JSON.generate(params)
    refute_match(/sender_id|account_id|recipient_id|balance_cents|owner_name/, serialized)
    refute_match(/Bob/, serialized, "accounts in the database must not reach the request")
  end

  test "turns a tool_use response into a ToolCall" do
    proposal = propose_with(tool_use_response("transfer_money", "recipient_name" => "Alice", "amount_cents" => 1_000))

    assert_equal [ ToolCall.new(name: "transfer_money", arguments: { "recipient_name" => "Alice", "amount_cents" => 1_000 }) ],
      proposal.tool_calls
  end

  test "passes unsafe arguments through unchanged" do
    unsafe = { "recipient_name" => " Alice ", "amount_cents" => "10.00", "sender_id" => @bob.id }
    proposal = propose_with(tool_use_response("transfer_money", unsafe))

    assert_equal [ ToolCall.new(name: "transfer_money", arguments: unsafe) ], proposal.tool_calls
  end

  test "passes unknown tool names through unchanged" do
    proposal = propose_with(tool_use_response("delete_account", "account" => "Alice"))

    assert_equal [ "delete_account" ], proposal.tool_calls.map(&:name)
  end

  test "a clarifying question produces no tool calls" do
    proposal = propose_with(
      "stop_reason" => "end_turn",
      "content" => [ { "type" => "text", "text" => "How much would you like to send to Alice?" } ]
    )

    assert_empty proposal.tool_calls
    assert_equal "How much would you like to send to Alice?", proposal.text
  end

  test "a response cut off at max_tokens produces no tool calls" do
    response = tool_use_response("transfer_money", "recipient_name" => "Alice", "amount_cents" => 1_000)
      .merge("stop_reason" => "max_tokens")

    assert_empty propose_with(response).tool_calls
  end

  test "a proposed transfer reaches confirmation without moving money" do
    proposal = propose_with(tool_use_response("transfer_money", "recipient_name" => "Alice", "amount_cents" => 1_000))

    result = assert_no_money_moved { handle_as(@bob, proposal) }

    assert_equal :confirmation_required, result.status
    assert_equal({ sender_id: @bob.id, recipient_id: @alice.id, recipient_name: "Alice", amount_cents: 1_000 }, result.data)
  end

  test "unsafe proposed arguments are rejected by the handler" do
    unsafe = { "recipient_name" => "Alice", "amount_cents" => 1_000, "sender_id" => @alice.id }
    proposal = propose_with(tool_use_response("transfer_money", unsafe))

    result = assert_no_money_moved { handle_as(@bob, proposal) }

    assert_equal :rejected, result.status
    assert_match(/unexpected arguments: sender_id/, result.error)
  end

  test "unknown proposed tools are denied by policy" do
    proposal = propose_with(tool_use_response("delete_account", "account" => "Alice"))

    result = assert_no_money_moved { handle_as(@bob, proposal) }

    assert_equal :rejected, result.status
    assert_match(/tool not allowed/, result.error)
  end

  private

  def capture_request(instruction)
    params = nil
    ToolCallProposer.new(send_request: ->(request) { params = request; { "content" => [] } }).call(instruction)
    params
  end

  def propose_with(response)
    ToolCallProposer.new(send_request: ->(_) { response }).call("Send $10 to Alice")
  end

  def tool_use_response(name, input)
    {
      "stop_reason" => "tool_use",
      "content" => [ { "type" => "tool_use", "id" => "toolu_test", "name" => name, "input" => input } ]
    }
  end

  def handle_as(account, proposal)
    ToolCallHandler.new(current_account: account).call(proposal.tool_calls.sole)
  end

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
