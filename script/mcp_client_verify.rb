#!/usr/bin/env ruby
# frozen_string_literal: true

require "mcp"
require "mcp/client/http"

endpoint, allow_id, approval_id, deny_id = ARGV

unless [endpoint, allow_id, approval_id, deny_id].all?
  warn "Usage: ruby script/mcp_client_verify.rb MCP_URL ALLOW_PRODUCT_ID APPROVAL_PRODUCT_ID DENY_PRODUCT_ID"
  exit 2
end

transport = MCP::Client::HTTP.new(url: endpoint)
client = MCP::Client.new(transport: transport)

begin
  client.connect(
    client_info: { name: "acting-for-demo-verifier", version: "1.0.0" },
    protocol_version: "2025-11-25"
  )

  tools = client.tools
  tool_names = tools.map(&:name)
  raise "Unexpected MCP tools: #{tool_names.inspect}" unless tool_names == ["purchase_product"]

  cases = [
    [allow_id, "allow", "delegation_allowed", true],
    [approval_id, "require_approval", "delegation_requires_approval", false],
    [deny_id, "deny", "no_matching_delegation", false]
  ]

  cases.each do |product_id, expected_status, expected_reason, expected_executed|
    response = client.call_tool(
      name: "purchase_product",
      arguments: { product_id: Integer(product_id) }
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

  puts "External MCP client verification: PASS"
ensure
  transport.close if transport.respond_to?(:close)
end
