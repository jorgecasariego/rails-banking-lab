require "test_helper"

class ToolPolicyTest < ActiveSupport::TestCase
  test "transfer_money requires confirmation" do
    assert_equal :confirm, ToolPolicy.decision_for("transfer_money")
  end

  test "denies tools it does not know" do
    [ "delete_account", "Transfer_Money", "transfer_money ", "", nil, :transfer_money ].each do |name|
      assert_equal :deny, ToolPolicy.decision_for(name), "expected #{name.inspect} to be denied"
    end
  end
end
