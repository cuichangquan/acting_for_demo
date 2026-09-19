class ShoppingAgentPurchase
  Result = Data.define(:principal, :agent, :product, :decision, :purchase)

  def self.call(product_id:, principal:, agent:)
    product = Product.find(product_id)
    decision = ActingFor.authorize(
      agent: agent, principal: principal, action: :purchase, resource: product,
      context: { amount: product.price }, audit_context_keys: [:amount]
    )

    purchase = if decision.allowed?
      Purchase.create!(
        user: principal,
        product:,
        amount: product.price,
        source: :shopping_agent
      )
    end

    Result.new(principal:, agent:, product:, decision:, purchase:)
  end
end
