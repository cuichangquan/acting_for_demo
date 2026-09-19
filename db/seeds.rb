principal = User.find_or_create_by!(name: "Demo User")
agent = ActingFor::Agent.find_or_create_by!(identifier: "shopping-agent") { |record| record.name = "Shopping Agent" }

[["Everyday Item", 800], ["Approval Item", 2_000], ["Expensive Item", 5_000]].each do |name, price|
  Product.find_or_create_by!(name:) { |product| product.price = price }
end

rules = [
  { effect: :allow, constraints: [{ field: "amount", operator: "lte", value: 1_000 }] },
  { effect: :require_approval, constraints: [
    { field: "amount", operator: "gt", value: 1_000 },
    { field: "amount", operator: "lte", value: 3_000 }
  ] }
]

rules.each do |rule|
  exists = ActingFor::Delegation.where(
    agent:, principal:, action: "purchase", resource_type: "Product",
    resource_id: nil, effect: rule[:effect].to_s, revoked_at: nil
  ).where("expires_at IS NULL OR expires_at > ?", ActingFor.current_time).any? do |delegation|
    delegation.constraints == rule[:constraints].map(&:stringify_keys)
  end

  ActingFor.delegate(agent:, principal:, action: :purchase, resource: Product, **rule) unless exists
end

puts "Seeded Demo User, Shopping Agent, 3 products, and 2 delegations."
