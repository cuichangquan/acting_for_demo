class DelegationSettingsController < ApplicationController
  before_action :load_demo_identity

  def show
    load_settings
  end

  def update
    DemoDelegationSettings.replace!(
      principal: @principal,
      agent: @agent,
      **settings_params.to_h.symbolize_keys
    )
    redirect_to delegation_settings_path, notice: "Delegation settings updated."
  rescue DemoDelegationSettings::InvalidSettings => error
    @error = error.message
    load_settings
    render :show, status: :unprocessable_entity
  end

  def reset
    DemoDelegationSettings.reset!(principal: @principal, agent: @agent)
    redirect_to delegation_settings_path, notice: "Delegation settings reset to demo defaults."
  end

  private

  def load_demo_identity
    @principal = User.find_by!(name: "Demo User")
    @agent = ActingFor::Agent.find_by!(identifier: "shopping-agent")
  end

  def load_settings
    @settings = DemoDelegationSettings.current(principal: @principal, agent: @agent)
  end

  def settings_params
    params.require(:delegation_settings).permit(:allow_max, :approval_max)
  end
end
