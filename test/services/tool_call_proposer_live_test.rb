require "test_helper"

# Smoke test against the real Anthropic API. It costs money and depends on
# the model, so it only runs with LIVE_LLM=1 and ANTHROPIC_API_KEY set.
# Deterministic coverage lives in ToolCallProposerTest.
class ToolCallProposerLiveTest < ActiveSupport::TestCase
  test "Send $10 to Alice becomes a confirmable transfer_money proposal" do
    skip "set LIVE_LLM=1 to call the real Anthropic API" unless ENV["LIVE_LLM"]

    alice = Account.create!(owner_name: "Alice", balance_cents: 0)
    bob = Account.create!(owner_name: "Bob", balance_cents: 5_000)

    proposal = ToolCallProposer.new.call("Send $10 to Alice")
    puts JSON.pretty_generate(proposal.raw_response)

    assert_equal [ "transfer_money" ], proposal.tool_calls.map(&:name)
    result = assert_no_difference "Transaction.count" do
      ToolCallHandler.new(current_account: bob).call(proposal.tool_calls.first)
    end
    assert_equal :confirmation_required, result.status
    assert_equal({ sender_id: bob.id, recipient_id: alice.id, recipient_name: "Alice", amount_cents: 1_000 }, result.data)
    assert_equal 5_000, bob.reload.balance_cents
  end
end
