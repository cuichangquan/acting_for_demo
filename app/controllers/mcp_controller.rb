require "mcp"

class McpController < ActionController::API
  def create
    server = MCP::Server.new(
      name: "acting_for_demo",
      title: "ActingFor Shopping Demo",
      version: "1.0.0",
      instructions: "Use list_products before purchase_product. Never guess product_id; delegated purchases must go through purchase_product and the Rails host authorization boundary.",
      tools: [ListProductsTool, PurchaseProductTool],
      server_context: DemoMcpIdentityResolver.resolve!(authorization_header: request.authorization)
    )

    options = {
      stateless: true,
      enable_json_response: true,
      serve_subscriptions_listen: false
    }
    options[:allowed_hosts] = ["www.example.com"] if Rails.env.test?

    transport = MCP::Server::Transports::StreamableHTTPTransport.new(server, **options)
    status, response_headers, body = transport.handle_request(request)

    response_headers.each { |key, value| response.set_header(key, value) }
    self.status = status
    self.response_body = body
  rescue DemoMcpIdentityResolver::Unauthorized
    response.set_header("WWW-Authenticate", 'Bearer realm="acting_for_demo_mcp"')
    head :unauthorized
  end
end
