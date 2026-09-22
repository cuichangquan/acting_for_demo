class ShopController < ApplicationController
  def index
    @principal = User.find_by!(name: "Demo User")
    @agent = ActingFor::Agent.find_by!(identifier: "shopping-agent")
    @products = Product.order(:price)
    @delegation_settings = DemoDelegationSettings.current(principal: @principal, agent: @agent)
  rescue DemoDelegationSettings::InvalidSettings => error
    @delegation_settings = nil
    @delegation_settings_error = error.message
  end
end
