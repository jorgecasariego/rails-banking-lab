require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "owner name is required" do
    account = Account.new(owner_name: nil)

    assert_not account.valid?
    assert_includes account.errors[:owner_name], "can't be blank"
  end
end
