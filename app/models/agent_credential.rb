require "digest"

class AgentCredential < ApplicationRecord
  belongs_to :agent, class_name: "ActingFor::Agent"

  validates :token_digest, presence: true, uniqueness: true

  class << self
    def issue!(agent:, token:)
      raise ArgumentError, "token must be present" if token.blank?

      create!(agent:, token_digest: digest(token))
    end

    def authenticate(token)
      return if token.blank?

      find_by(token_digest: digest(token))&.agent
    end

    def digest(token)
      Digest::SHA256.hexdigest(token.to_s)
    end
  end
end
