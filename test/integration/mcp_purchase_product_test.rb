require "test_helper"
require "json"

class McpPurchaseProductTest < ActionDispatch::IntegrationTest
  setup do
    @principal = User.create!(name: "Demo User")
    @agent = ActingFor::Agent.create!(identifier: "shopping-agent", name: "Shopping Agent")
    @bearer_token = "test-shopping-agent-bearer-token"
    AgentCredential.issue!(agent: @agent, token: @bearer_token)

    @everyday = Product.create!(name: "Everyday Item", price: 800)
    @approval = Product.create!(name: "Approval Item", price: 2_000)
    @expensive = Product.create!(name: "Expensive Item", price: 5_000)

    ActingFor.delegate(
      agent: @agent,
      principal: @principal,
      action: :purchase,
      resource: Product,
      constraints: [{ field: "amount", operator: "lte", value: 1_000 }],
      effect: :allow
    )

    ActingFor.delegate(
      agent: @agent,
      principal: @principal,
      action: :purchase,
      resource: Product,
      constraints: [
        { field: "amount", operator: "gt", value: 1_000 },
        { field: "amount", operator: "lte", value: 3_000 }
      ],
      effect: :require_approval
    )
  end

  test "requires a bearer token before entering the MCP transport" do
    assert_no_difference ["Purchase.count", "ActingFor::AuditEvent.count"] do
      payload = mcp_request(method: "tools/list", token: nil)

      assert_response :unauthorized
      assert_nil payload
      assert_equal 'Bearer realm="acting_for_demo_mcp"', response.headers["WWW-Authenticate"]
    end
  end

  test "rejects an invalid bearer token before entering the MCP transport" do
    assert_no_difference ["Purchase.count", "ActingFor::AuditEvent.count"] do
      payload = mcp_request(method: "tools/list", token: "invalid-token")

      assert_response :unauthorized
      assert_nil payload
    end
  end

  test "lists purchase_product as the only MCP tool for an authenticated agent" do
    payload = mcp_request(method: "tools/list")

    assert_response :success
    tools = payload.fetch("result").fetch("tools")
    assert_equal ["purchase_product"], tools.map { |tool| tool.fetch("name") }
    assert_equal ["product_id"], tools.first.fetch("inputSchema").fetch("required")
  end

  test "allow executes purchase and records audit through MCP" do
    assert_difference ["Purchase.count", "ActingFor::AuditEvent.count"], 1 do
      result = call_purchase_product(@everyday)

      assert_equal "allow", result.fetch("status")
      assert_equal "delegation_allowed", result.fetch("reason_code")
      assert_equal true, result.fetch("executed")
      assert result.fetch("purchase_id").present?
    end

    assert_equal({ "amount" => 800 }, ActingFor::AuditEvent.last.sanitized_context)
  end

  test "require approval does not execute purchase and records audit through MCP" do
    assert_no_difference "Purchase.count" do
      assert_difference "ActingFor::AuditEvent.count", 1 do
        result = call_purchase_product(@approval)

        assert_equal "require_approval", result.fetch("status")
        assert_equal "delegation_requires_approval", result.fetch("reason_code")
        assert_equal false, result.fetch("executed")
        assert_nil result["purchase_id"]
      end
    end
  end

  test "deny does not execute purchase and records audit through MCP" do
    assert_no_difference "Purchase.count" do
      assert_difference "ActingFor::AuditEvent.count", 1 do
        result = call_purchase_product(@expensive)

        assert_equal "deny", result.fetch("status")
        assert_equal "no_matching_delegation", result.fetch("reason_code")
        assert_equal false, result.fetch("executed")
        assert_nil result["purchase_id"]
      end
    end
  end

  test "the bearer token determines the ActingFor agent" do
    other_agent = ActingFor::Agent.create!(identifier: "other-agent", name: "Other Agent")
    other_token = "other-agent-bearer-token"
    AgentCredential.issue!(agent: other_agent, token: other_token)

    assert_no_difference "Purchase.count" do
      assert_difference "ActingFor::AuditEvent.count", 1 do
        result = call_purchase_product(@everyday, token: other_token)

        assert_equal "deny", result.fetch("status")
        assert_equal "no_matching_delegation", result.fetch("reason_code")
        assert_equal false, result.fetch("executed")
      end
    end

    assert_equal "other-agent", ActingFor::AuditEvent.last.agent_identifier
  end

  test "tool arguments cannot override trusted amount agent or principal" do
    assert_no_difference ["Purchase.count", "ActingFor::AuditEvent.count"] do
      response_payload = mcp_request(
        method: "tools/call",
        params: {
          name: "purchase_product",
          arguments: {
            product_id: @expensive.id,
            amount: 100,
            agent_id: @agent.id,
            principal_id: @principal.id
          }
        }
      )

      assert response_payload["error"] || response_payload.dig("result", "isError")
    end
  end

  private

  def call_purchase_product(product, token: @bearer_token)
    response_payload = mcp_request(
      method: "tools/call",
      params: {
        name: "purchase_product",
        arguments: { product_id: product.id }
      },
      token:
    )

    assert_response :success
    response_payload.fetch("result").fetch("structuredContent")
  end

  def mcp_request(method:, params: nil, token: @bearer_token)
    @mcp_request_id ||= 0
    @mcp_request_id += 1

    request_payload = {
      jsonrpc: "2.0",
      id: @mcp_request_id,
      method:
    }
    request_payload[:params] = params if params

    headers = {
      "Content-Type" => "application/json",
      "Accept" => "application/json",
      "MCP-Protocol-Version" => "2025-11-25"
    }
    headers["Authorization"] = "Bearer #{token}" if token

    post "/mcp",
      params: JSON.generate(request_payload),
      headers:

    return if response.body.blank?

    JSON.parse(response.body)
  end
end
