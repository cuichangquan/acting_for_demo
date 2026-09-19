class AuditEventsController < ApplicationController
  def index
    @audit_events = ActingFor::AuditEvent.order(created_at: :desc)
  end
end
