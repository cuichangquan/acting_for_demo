# This migration comes from acting_for (originally 20260918030001)
class CreateActingForAgents < ActiveRecord::Migration[8.0]
  def change
    create_table :acting_for_agents do |t|
      t.string :identifier, null: false
      t.string :name
      t.timestamps null: false
    end

    add_index :acting_for_agents, :identifier, unique: true
  end
end
