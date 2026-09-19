class PurchasesController < ApplicationController
  def index
    @purchases = Purchase.includes(:user, :product).order(created_at: :desc)
  end
end
