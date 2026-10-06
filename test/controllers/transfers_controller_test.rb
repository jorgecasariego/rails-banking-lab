require "test_helper"

class TransfersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = Account.create!(owner_name: "Alice", balance_cents: 10_000)
    @bob = Account.create!(owner_name: "Bob", balance_cents: 2_000)
  end

  test "GET /transfers/new renders the transfer form" do
    get new_transfer_url

    assert_response :success
    assert_select "h1", "Transfer money"
    assert_select "form[action=?][method=?]", transfers_path, "post" do
      assert_select "select[name=?]", "transfer[sender_id]" do
        assert_select "option", text: "Alice"
        assert_select "option", text: "Bob"
      end
      assert_select "select[name=?]", "transfer[recipient_id]"
      assert_select "input[name=?]", "transfer[amount_cents]"
    end
  end

  test "POST /transfers moves money and redirects to the sender's transactions" do
    assert_difference "Transaction.count", 2 do
      post transfers_url, params: {
        transfer: { sender_id: @alice.id, recipient_id: @bob.id, amount_cents: "2500" }
      }
    end

    assert_redirected_to account_transactions_path(@alice)
    assert_equal 7_500, @alice.reload.balance_cents
    assert_equal 4_500, @bob.reload.balance_cents
    assert_equal(-2_500, @alice.transactions.last.amount_cents)
    assert_equal 2_500, @bob.transactions.last.amount_cents
  end

  test "POST /transfers with insufficient funds re-renders the form with the error" do
    assert_no_difference "Transaction.count" do
      post transfers_url, params: {
        transfer: { sender_id: @alice.id, recipient_id: @bob.id, amount_cents: "10001" }
      }
    end

    assert_response :unprocessable_entity
    assert_select "p", "insufficient balance"
    assert_select "form[action=?]", transfers_path
    assert_equal 10_000, @alice.reload.balance_cents
    assert_equal 2_000, @bob.reload.balance_cents
  end
end
