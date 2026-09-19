require "test_helper"

class ShoppingAgentPurchaseTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @principal = User.create!(name: "Demo User")
    @agent = ActingFor::Agent.create!(identifier: "shopping-agent", name: "Shopping Agent")
    @everyday = Product.create!(name: "Everyday Item", price: 800)
    @approval = Product.create!(name: "Approval Item", price: 2_000)
    @expensive = Product.create!(name: "Expensive Item", price: 5_000)
    @allow = delegate_allow
    delegate_approval
  end

  test "allow creates a purchase and audit" do
    assert_difference ["Purchase.count", "ActingFor::AuditEvent.count"], 1 do
      result = call_for(@everyday)
      assert_equal :allow, result.decision.status
      assert result.purchase.persisted?
      assert_equal "shopping_agent", result.purchase.source
    end
    assert_equal({ "amount" => 800 }, ActingFor::AuditEvent.last.sanitized_context)
  end

  test "require approval creates audit but no purchase" do
    assert_no_difference "Purchase.count" do
      assert_difference "ActingFor::AuditEvent.count", 1 do
        result = call_for(@approval)
        assert_equal :require_approval, result.decision.status
        assert_nil result.purchase
      end
    end
  end

  test "unmatched amount denies closed with audit and no purchase" do
    assert_no_difference "Purchase.count" do
      assert_difference "ActingFor::AuditEvent.count", 1 do
        assert_equal :deny, call_for(@expensive).decision.status
      end
    end
  end

  test "forged client amount is ignored" do
    assert_no_difference "Purchase.count" do
      post purchase_requests_path, params: { product_id: @expensive.id, amount: 100 }
    end
    assert_response :success
    assert_includes response.body, "Trusted Amount"
    assert_includes response.body, "¥5,000"
    assert_includes response.body, "DENY"
    assert_equal({ "amount" => 5_000 }, ActingFor::AuditEvent.last.sanitized_context)
  end

  test "revoked delegation denies" do
    @allow.revoke!
    assert_no_difference("Purchase.count") { assert_equal :deny, call_for(@everyday).decision.status }
  end

  test "expired delegation denies" do
    @allow.revoke!
    expiring = delegate_allow(expires_at: 1.minute.from_now)
    travel_to 2.minutes.from_now do
      assert expiring.expires_at.past?
      assert_no_difference("Purchase.count") { assert_equal :deny, call_for(@everyday).decision.status }
    end
  end

  test "different agent denies" do
    other = ActingFor::Agent.create!(identifier: "other-agent", name: "Other Agent")
    assert_equal :deny, call_for(@everyday, agent: other).decision.status
  end

  test "different principal denies" do
    other = User.create!(name: "Other User")
    assert_equal :deny, call_for(@everyday, principal: other).decision.status
  end

  private

  def delegate_allow(expires_at: nil)
    ActingFor.delegate(agent: @agent, principal: @principal, action: :purchase,
      resource: Product, constraints: [{ field: "amount", operator: "lte", value: 1_000 }],
      effect: :allow, expires_at:)
  end

  def delegate_approval
    ActingFor.delegate(agent: @agent, principal: @principal, action: :purchase,
      resource: Product, constraints: [
        { field: "amount", operator: "gt", value: 1_000 },
        { field: "amount", operator: "lte", value: 3_000 }
      ], effect: :require_approval)
  end

  def call_for(product, principal: @principal, agent: @agent)
    ShoppingAgentPurchase.call(product_id: product.id, principal:, agent:)
  end
end
