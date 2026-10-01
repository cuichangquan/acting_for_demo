principal = User.find_or_create_by!(name: "Demo User")
agent = ActingFor::Agent.find_or_create_by!(identifier: "shopping-agent") { |record| record.name = "Shopping Agent" }

[["Everyday Item", 800], ["Approval Item", 2_000], ["Expensive Item", 5_000]].each do |name, price|
  Product.find_or_create_by!(name:) { |product| product.price = price }
end

DemoDelegationSettings.ensure_defaults!(principal:, agent:)

demo_mcp_token = ENV["DEMO_MCP_BEARER_TOKEN"].presence
if demo_mcp_token.nil?
  raise "DEMO_MCP_BEARER_TOKEN is required in production" if Rails.env.production?

  demo_mcp_token = "acting-for-demo-shopping-agent-token"
end

credential = AgentCredential.find_or_initialize_by(agent:)
credential.token_digest = AgentCredential.digest(demo_mcp_token)
credential.save!

puts "Seeded Demo User, Shopping Agent, 3 products, 2 delegations, and an MCP Agent credential."
