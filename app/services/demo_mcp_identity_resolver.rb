class DemoMcpIdentityResolver
  class Unauthorized < StandardError; end

  PRINCIPAL_NAME = "Demo User"
  BEARER_PATTERN = /\ABearer[ \t]+([^\s]+)\z/i

  class << self
    def resolve!(authorization_header:)
      token = extract_bearer_token!(authorization_header)
      agent = AgentCredential.authenticate(token)
      raise Unauthorized, "invalid bearer token" unless agent

      {
        agent:,
        principal: User.find_by!(name: PRINCIPAL_NAME)
      }
    end

    private

    def extract_bearer_token!(authorization_header)
      match = BEARER_PATTERN.match(authorization_header.to_s)
      raise Unauthorized, "bearer token required" unless match

      match[1]
    end
  end
end
