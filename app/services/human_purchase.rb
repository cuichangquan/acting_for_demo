class HumanPurchase
  Result = Data.define(:principal, :product, :purchase)

  def self.call(product_id:, principal:)
    product = Product.find(product_id)
    purchase = Purchase.create!(
      user: principal,
      product:,
      amount: product.price,
      source: :human
    )

    Result.new(principal:, product:, purchase:)
  end
end
