require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    account = Account.create!(
      owner_name: "Jorge",
      balance_cents: 10_000
    )

    account.transactions.create!(
      description: "Initial deposit",
      amount_cents: 10_000
    )

    get account_transactions_url(account)

    assert_response :success
    assert_select "h1", "Transactions for Jorge"
    assert_select "li", text: /Initial deposit/
  end
end
