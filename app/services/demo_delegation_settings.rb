class DemoDelegationSettings
  DEFAULT_ALLOW_MAX = 1_000
  DEFAULT_APPROVAL_MAX = 3_000

  Settings = Data.define(:allow_max, :approval_max)
  class InvalidSettings < StandardError; end

  def self.current(principal:, agent:)
    delegations = active_delegations(principal:, agent:)
    allow_delegation = delegations.find { |delegation| delegation.effect == "allow" }
    approval_delegation = delegations.find { |delegation| delegation.effect == "require_approval" }

    Settings.new(
      allow_max: constraint_value!(allow_delegation, operator: "lte"),
      approval_max: constraint_value!(approval_delegation, operator: "lte")
    )
  end

  def self.replace!(principal:, agent:, allow_max:, approval_max:)
    allow_max = parse_integer(allow_max, "Allow maximum")
    approval_max = parse_integer(approval_max, "Approval maximum")
    validate_ranges!(allow_max:, approval_max:)

    ActingFor::Delegation.transaction do
      active_delegations(principal:, agent:, lock: true).each(&:revoke!)
      create_delegations!(principal:, agent:, allow_max:, approval_max:)
    end

    Settings.new(allow_max:, approval_max:)
  end

  def self.reset!(principal:, agent:)
    replace!(
      principal:,
      agent:,
      allow_max: DEFAULT_ALLOW_MAX,
      approval_max: DEFAULT_APPROVAL_MAX
    )
  end

  def self.ensure_defaults!(principal:, agent:)
    return if active_delegations(principal:, agent:).any?

    create_delegations!(
      principal:,
      agent:,
      allow_max: DEFAULT_ALLOW_MAX,
      approval_max: DEFAULT_APPROVAL_MAX
    )
  end

  def self.active_delegations(principal:, agent:, lock: false)
    relation = ActingFor::Delegation.where(
      agent:,
      principal:,
      action: "purchase",
      resource_type: "Product",
      resource_id: nil,
      revoked_at: nil
    ).where("expires_at IS NULL OR expires_at > ?", ActingFor.current_time)
    relation = relation.lock if lock
    relation.to_a
  end
  private_class_method :active_delegations

  def self.create_delegations!(principal:, agent:, allow_max:, approval_max:)
    ActingFor.delegate(
      agent:,
      principal:,
      action: :purchase,
      resource: Product,
      constraints: [{ field: "amount", operator: "lte", value: allow_max }],
      effect: :allow
    )
    ActingFor.delegate(
      agent:,
      principal:,
      action: :purchase,
      resource: Product,
      constraints: [
        { field: "amount", operator: "gt", value: allow_max },
        { field: "amount", operator: "lte", value: approval_max }
      ],
      effect: :require_approval
    )
  end
  private_class_method :create_delegations!

  def self.constraint_value!(delegation, operator:)
    constraint = delegation&.constraints&.find do |item|
      item["field"] == "amount" && item["operator"] == operator
    end
    return constraint["value"] if constraint && constraint["value"].is_a?(Integer)

    raise InvalidSettings, "The active demo delegations do not have the expected shape."
  end
  private_class_method :constraint_value!

  def self.parse_integer(value, label)
    return value if value.is_a?(Integer)

    Integer(value, 10)
  rescue ArgumentError, TypeError
    raise InvalidSettings, "#{label} must be an integer."
  end
  private_class_method :parse_integer

  def self.validate_ranges!(allow_max:, approval_max:)
    raise InvalidSettings, "Allow maximum must be at least 0." if allow_max.negative?
    return if approval_max > allow_max

    raise InvalidSettings, "Approval maximum must be greater than allow maximum."
  end
  private_class_method :validate_ranges!
end
