require "test_helper"

class HumanPurchaseTest < ActionDispatch::IntegrationTest
  setup do
    @principal = User.create!(name: "Demo User")
    @products = [
      Product.create!(name: "Everyday Item", price: 800),
      Product.create!(name: "Approval Item", price: 2_000),
      Product.create!(name: "Expensive Item", price: 5_000)
    ]
  end

  test "human directly purchases every demo product without an ActingFor audit event" do
    @products.each do |product|
      assert_difference "Purchase.count", 1 do
        assert_no_difference "ActingFor::AuditEvent.count" do
          result = HumanPurchase.call(product_id: product.id, principal: @principal)
          assert_equal product.price, result.purchase.amount
          assert_equal "human", result.purchase.source
        end
      end
    end
  end

  test "human purchase endpoint ignores a forged client amount" do
    product = @products.last

    assert_difference "Purchase.count", 1 do
      assert_no_difference "ActingFor::AuditEvent.count" do
        post human_purchases_path, params: { product_id: product.id, amount: 100 }
      end
    end

    assert_response :success
    assert_equal 5_000, Purchase.order(:created_at).last.amount
    assert_includes response.body, "NOT INVOLVED"
    assert_includes response.body, "¥5,000"
  end
end
