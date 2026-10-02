#!/usr/bin/env ruby
# frozen_string_literal: true

require "mcp"
require "mcp/client/http"

endpoint, bearer_token = ARGV

unless endpoint && bearer_token
  warn "Usage: ruby script/mcp_client_verify.rb MCP_URL BEARER_TOKEN"
  exit 2
end

transport = MCP::Client::HTTP.new(
  url: endpoint,
  headers: { "Authorization" => "Bearer #{bearer_token}" }
)
client = MCP::Client.new(transport: transport)

begin
  client.connect(
    client_info: { name: "acting-for-demo-verifier", version: "1.0.0" },
    protocol_version: "2025-11-25"
  )

  tools = client.tools
  tool_names = tools.map(&:name)
  expected_tools = ["list_products", "purchase_product"]
  raise "Unexpected MCP tools: #{tool_names.inspect}" unless tool_names == expected_tools

  list_response = client.call_tool(name: "list_products", arguments: {})
  list_payload = list_response.dig("result", "structuredContent")
  raise "Missing list_products structuredContent: #{list_response.inspect}" unless list_payload.is_a?(Hash)

  products = list_payload["products"]
  raise "Missing products array: #{list_payload.inspect}" unless products.is_a?(Array)

  products_by_price = products.to_h do |product|
    [Integer(product.fetch("price")), product]
  end

  expected_products = {
    800 => "Everyday Item",
    2_000 => "Approval Item",
    5_000 => "Expensive Item"
  }

  expected_products.each do |price, expected_name|
    product = products_by_price.fetch(price)
    raise "Unexpected product for price #{price}: #{product.inspect}" unless product.fetch("name") == expected_name
    puts "MCP discovered product=#{product.fetch("id")}: #{expected_name} / price=#{price}"
  end

  cases = [
    [800, "allow", "delegation_allowed", true],
    [2_000, "require_approval", "delegation_requires_approval", false],
    [5_000, "deny", "no_matching_delegation", false]
  ]

  cases.each do |price, expected_status, expected_reason, expected_executed|
    product = products_by_price.fetch(price)
    product_id = Integer(product.fetch("id"))

    response = client.call_tool(
      name: "purchase_product",
      arguments: { product_id: }
    )

    payload = response.dig("result", "structuredContent")
    raise "Missing structuredContent: #{response.inspect}" unless payload.is_a?(Hash)

    actual = {
      "status" => payload["status"],
      "reason_code" => payload["reason_code"],
      "executed" => payload["executed"]
    }
    expected = {
      "status" => expected_status,
      "reason_code" => expected_reason,
      "executed" => expected_executed
    }

    raise "Unexpected result for product #{product_id}: #{actual.inspect}" unless actual == expected

    puts "MCP product=#{product_id}: #{expected_status} / #{expected_reason} / executed=#{expected_executed}"
  end

  puts "External MCP client discovery + purchase verification with Bearer auth: PASS"
ensure
  transport.close if transport.respond_to?(:close)
end
