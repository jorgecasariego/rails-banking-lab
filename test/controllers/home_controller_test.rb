require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "GET / shows the welcome page" do
    get root_path
    assert_response :success
    assert_select "h1", "Rails Banking Lab"
    assert_select "p", "Welcome!"
  end
end
