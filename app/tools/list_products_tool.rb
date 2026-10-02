require "json"
require "mcp"

class ListProductsTool < MCP::Tool
  tool_name "list_products"
  title "List Products"
  description "Lists current demo products from the Rails database. Use this before purchase_product and never guess product_id."

  input_schema(
    properties: {},
    additionalProperties: false
  )

  annotations(
    read_only_hint: true,
    destructive_hint: false,
    idempotent_hint: true,
    open_world_hint: false,
    title: "List Products"
  )

  class << self
    def call(server_context:)
      products = Product.order(:id).map do |product|
        {
          id: product.id,
          name: product.name,
          price: product.price
        }
      end

      MCP::Tool::Response.new(
        [{ type: "text", text: JSON.generate(products) }],
        structured_content: { products: }
      )
    end
  end
end
