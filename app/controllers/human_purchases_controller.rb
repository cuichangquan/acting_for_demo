class HumanPurchasesController < ApplicationController
  def create
    @result = HumanPurchase.call(
      product_id: params.require(:product_id),
      principal: User.find_by!(name: "Demo User")
    )
  end
end
