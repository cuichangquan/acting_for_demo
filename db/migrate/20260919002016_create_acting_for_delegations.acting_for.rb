# This migration comes from acting_for (originally 20260918030002)
class CreateActingForDelegations < ActiveRecord::Migration[8.0]
  def change
    create_table :acting_for_delegations do |t|
      t.bigint :agent_id, null: false
      t.string :principal_type, null: false
      t.string :principal_id, null: false
      t.string :action, null: false
      t.string :resource_type
      t.string :resource_id
      t.string :effect, null: false
      t.json :constraints, null: false, default: []
      t.datetime :expires_at
      t.datetime :revoked_at
      t.timestamps null: false
    end

    add_foreign_key :acting_for_delegations, :acting_for_agents, column: :agent_id
    add_index :acting_for_delegations, :agent_id
    add_index :acting_for_delegations,
              %i[agent_id principal_type principal_id action resource_type],
              name: "idx_acting_for_delegations_authorization_lookup"

    add_check_constraint :acting_for_delegations,
                         "resource_type IS NOT NULL OR resource_id IS NULL",
                         name: "chk_acting_for_delegations_resource_scope"
    add_check_constraint :acting_for_delegations,
                         "effect IN ('allow', 'require_approval')",
                         name: "chk_acting_for_delegations_effect"
  end
end
