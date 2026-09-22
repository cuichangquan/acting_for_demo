require "test_helper"

class DelegationSettingsTest < ActionDispatch::IntegrationTest
  setup do
    @principal = User.create!(name: "Demo User")
    @agent = ActingFor::Agent.create!(identifier: "shopping-agent", name: "Shopping Agent")
    @everyday = Product.create!(name: "Everyday Item", price: 800)
    @approval = Product.create!(name: "Approval Item", price: 2_000)
    @expensive = Product.create!(name: "Expensive Item", price: 5_000)
    DemoDelegationSettings.reset!(principal: @principal, agent: @agent)
  end

  test "defaults are 1000 and 3000" do
    settings = current_settings

    assert_equal 1_000, settings.allow_max
    assert_equal 3_000, settings.approval_max
  end

  test "replacement changes agent authorization and revokes old delegations" do
    old_ids = active_delegations.map(&:id)

    DemoDelegationSettings.replace!(
      principal: @principal, agent: @agent, allow_max: "2500", approval_max: "6000"
    )

    assert_equal [2_500, 6_000], current_settings.deconstruct
    assert ActingFor::Delegation.where(id: old_ids).all? { |delegation| delegation.revoked_at.present? }
    assert_equal :allow, call_for(@approval).decision.status
    assert_equal :require_approval, call_for(@expensive).decision.status
  end

  test "invalid settings preserve existing delegations" do
    ids_and_timestamps = active_delegations.map { |delegation| [delegation.id, delegation.revoked_at] }

    assert_raises(DemoDelegationSettings::InvalidSettings) do
      DemoDelegationSettings.replace!(
        principal: @principal, agent: @agent, allow_max: "3000", approval_max: "2000"
      )
    end

    assert_equal ids_and_timestamps, active_delegations.map { |delegation| [delegation.id, delegation.revoked_at] }
    assert_equal [1_000, 3_000], current_settings.deconstruct
  end

  test "non-integer settings show an error and preserve existing delegations" do
    ids = active_delegations.map(&:id)

    patch delegation_settings_path,
      params: { delegation_settings: { allow_max: "1.5", approval_max: "6000" } }

    assert_response :unprocessable_entity
    assert_includes response.body, "must be an integer"
    assert_equal ids, active_delegations.map(&:id)
  end

  test "replacement rolls back revocation when creating a new delegation fails" do
    original = ActingFor.method(:delegate)
    calls = 0
    failing_delegate = lambda do |**arguments|
      calls += 1
      raise ActiveRecord::RecordInvalid if calls == 2

      original.call(**arguments)
    end
    ids = active_delegations.map(&:id)

    ActingFor.singleton_class.define_method(:delegate, failing_delegate)
    begin
      assert_raises(ActiveRecord::RecordInvalid) do
        DemoDelegationSettings.replace!(
          principal: @principal, agent: @agent, allow_max: 2_500, approval_max: 6_000
        )
      end
    ensure
      ActingFor.singleton_class.define_method(:delegate, original)
    end

    assert_equal ids, active_delegations.map(&:id)
    assert_equal [1_000, 3_000], current_settings.deconstruct
  end

  test "reset restores demo defaults and original outcomes" do
    DemoDelegationSettings.replace!(
      principal: @principal, agent: @agent, allow_max: 2_500, approval_max: 6_000
    )

    post reset_delegation_settings_path

    assert_redirected_to delegation_settings_path
    assert_equal [1_000, 3_000], current_settings.deconstruct
    assert_equal :require_approval, call_for(@approval).decision.status
    assert_equal :deny, call_for(@expensive).decision.status
  end

  test "shop renders current delegation limits" do
    DemoDelegationSettings.replace!(
      principal: @principal, agent: @agent, allow_max: 2_500, approval_max: 6_000
    )

    get root_path

    assert_response :success
    assert_includes response.body, "¥2,500"
    assert_includes response.body, "¥2,501"
    assert_includes response.body, "¥6,000"
  end

  test "shop remains usable and purchase fails closed when allow delegation is revoked" do
    active_delegations.find { |delegation| delegation.effect == "allow" }.revoke!

    get root_path

    assert_response :success
    assert_includes response.body, "Delegation configuration is incomplete"
    assert_includes response.body, "Ask Shopping Agent to Buy"

    assert_no_difference "Purchase.count" do
      assert_difference "ActingFor::AuditEvent.count", 1 do
        post purchase_requests_path, params: { product_id: @everyday.id }
      end
    end

    assert_response :success
    assert_includes response.body, "DENY"
    assert_includes response.body, "NOT EXECUTED"
  end


  private

  def current_settings
    DemoDelegationSettings.current(principal: @principal, agent: @agent)
  end

  def active_delegations
    ActingFor::Delegation.where(
      agent: @agent,
      principal: @principal,
      action: "purchase",
      resource_type: "Product",
      resource_id: nil,
      revoked_at: nil
    ).order(:id).to_a
  end

  def call_for(product)
    ShoppingAgentPurchase.call(product_id: product.id, principal: @principal, agent: @agent)
  end
end
