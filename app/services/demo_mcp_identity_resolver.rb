class DemoMcpIdentityResolver
  # Development-only identity mapping for the local reference demo.
  #
  # This is intentionally not authentication. A production host must replace
  # this boundary with a trusted identity source (OAuth/OIDC/API credentials,
  # MCP authorization context, or another authenticated mechanism).
  def self.resolve!
    {
      agent: ActingFor::Agent.find_by!(identifier: "shopping-agent"),
      principal: User.find_by!(name: "Demo User")
    }
  end
end
