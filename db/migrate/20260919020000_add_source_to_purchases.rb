class AddSourceToPurchases < ActiveRecord::Migration[8.0]
  def change
    add_column :purchases, :source, :string, null: false, default: "shopping_agent"
    add_check_constraint :purchases,
      "source IN ('human', 'shopping_agent')",
      name: "chk_purchases_source"
  end
end
