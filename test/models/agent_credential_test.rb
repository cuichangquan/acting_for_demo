require "test_helper"

class AgentCredentialTest < ActiveSupport::TestCase
  test "issue stores only a token digest and authenticates the agent" do
    agent = ActingFor::Agent.create!(identifier: "credential-test-agent", name: "Credential Test Agent")
    token = "test-bearer-token"

    credential = AgentCredential.issue!(agent:, token:)

    assert_equal AgentCredential.digest(token), credential.token_digest
    refute_equal token, credential.token_digest
    assert_equal agent, AgentCredential.authenticate(token)
  end

  test "authenticate returns nil for an unknown token" do
    assert_nil AgentCredential.authenticate("unknown-token")
  end
end
