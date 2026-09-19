# This migration comes from acting_for (originally 20260918030003)
class CreateActingForAuditEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :acting_for_audit_events do |t|
      t.bigint :agent_id, null: false
      t.string :agent_identifier, null: false
      t.string :principal_type, null: false
      t.string :principal_id, null: false
      t.string :action, null: false
      t.string :resource_type
      t.string :resource_id
      t.string :decision, null: false
      t.string :reason_code, null: false
      t.json :matched_delegation_ids, null: false, default: []
      t.json :sanitized_context, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_check_constraint :acting_for_audit_events,
                         "resource_type IS NOT NULL OR resource_id IS NULL",
                         name: "chk_acting_for_audit_events_resource_scope"
    add_check_constraint :acting_for_audit_events,
                         "decision IN ('allow', 'deny', 'require_approval')",
                         name: "chk_acting_for_audit_events_decision"
    add_check_constraint :acting_for_audit_events,
                         "reason_code IN ('delegation_allowed', 'delegation_requires_approval', " \
                         "'no_matching_delegation')",
                         name: "chk_acting_for_audit_events_reason_code"
  end
end
