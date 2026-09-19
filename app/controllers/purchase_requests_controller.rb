class PurchaseRequestsController < ApplicationController
  def create
    @result = ShoppingAgentPurchase.call(
      product_id: params.require(:product_id),
      principal: User.find_by!(name: "Demo User"),
      agent: ActingFor::Agent.find_by!(identifier: "shopping-agent")
    )
  end
end
