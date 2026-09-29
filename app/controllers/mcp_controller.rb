require "mcp"

class McpController < ActionController::API
  def create
    server = MCP::Server.new(
      name: "acting_for_demo",
      title: "ActingFor Shopping Demo",
      version: "1.0.0",
      instructions: "Use purchase_product to request a delegated purchase through the Rails host.",
      tools: [PurchaseProductTool],
      server_context: DemoMcpIdentityResolver.resolve!
    )

    options = {
      stateless: true,
      enable_json_response: true,
      serve_subscriptions_listen: false
    }
    options[:allowed_hosts] = ["www.example.com"] if Rails.env.test?

    transport = MCP::Server::Transports::StreamableHTTPTransport.new(server, **options)
    status, headers, body = transport.handle_request(request)
    response_body = body.respond_to?(:first) ? body.first : body

    if response_body.nil? || response_body == ""
      head status, headers:
    else
      render json: response_body, status:, headers:
    end
  end
end
