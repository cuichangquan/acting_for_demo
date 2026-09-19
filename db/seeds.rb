principal = User.find_or_create_by!(name: "Demo User")
agent = ActingFor::Agent.find_or_create_by!(identifier: "shopping-agent") { |record| record.name = "Shopping Agent" }

[["Everyday Item", 800], ["Approval Item", 2_000], ["Expensive Item", 5_000]].each do |name, price|
  Product.find_or_create_by!(name:) { |product| product.price = price }
end

DemoDelegationSettings.ensure_defaults!(principal:, agent:)

puts "Seeded Demo User, Shopping Agent, 3 products, and 2 delegations."
