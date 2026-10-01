class CreateAgentCredentials < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_credentials do |t|
      t.references :agent, null: false, foreign_key: { to_table: :acting_for_agents }
      t.string :token_digest, null: false

      t.timestamps
    end

    add_index :agent_credentials, :token_digest, unique: true
  end
end
