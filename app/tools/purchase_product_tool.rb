require "json"
require "mcp"

class PurchaseProductTool < MCP::Tool
  tool_name "purchase_product"
  title "Purchase Product"
  description "Requests a delegated purchase for one product through the Rails host authorization boundary."

  input_schema(
    properties: {
      product_id: { type: "integer" }
    },
    required: ["product_id"],
    additionalProperties: false
  )

  annotations(
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: false,
    open_world_hint: false,
    title: "Purchase Product"
  )

  class << self
    def call(product_id:, server_context:)
      result = ShoppingAgentPurchase.call(
        product_id:,
        principal: server_context.fetch(:principal),
        agent: server_context.fetch(:agent)
      )

      payload = {
        status: result.decision.status.to_s,
        reason_code: result.decision.reason_code.to_s,
        executed: result.purchase.present?,
        purchase_id: result.purchase&.id
      }

      MCP::Tool::Response.new(
        [{ type: "text", text: JSON.generate(payload) }],
        structured_content: payload
      )
    end
  end
end
