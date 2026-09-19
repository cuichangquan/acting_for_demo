# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_09_19_020000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "acting_for_agents", force: :cascade do |t|
    t.string "identifier", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["identifier"], name: "index_acting_for_agents_on_identifier", unique: true
  end

  create_table "acting_for_audit_events", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.string "agent_identifier", null: false
    t.string "principal_type", null: false
    t.string "principal_id", null: false
    t.string "action", null: false
    t.string "resource_type"
    t.string "resource_id"
    t.string "decision", null: false
    t.string "reason_code", null: false
    t.json "matched_delegation_ids", default: [], null: false
    t.json "sanitized_context", default: {}, null: false
    t.datetime "created_at", null: false
    t.check_constraint "decision::text = ANY (ARRAY['allow'::character varying::text, 'deny'::character varying::text, 'require_approval'::character varying::text])", name: "chk_acting_for_audit_events_decision"
    t.check_constraint "reason_code::text = ANY (ARRAY['delegation_allowed'::character varying::text, 'delegation_requires_approval'::character varying::text, 'no_matching_delegation'::character varying::text])", name: "chk_acting_for_audit_events_reason_code"
    t.check_constraint "resource_type IS NOT NULL OR resource_id IS NULL", name: "chk_acting_for_audit_events_resource_scope"
  end

  create_table "acting_for_delegations", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.string "principal_type", null: false
    t.string "principal_id", null: false
    t.string "action", null: false
    t.string "resource_type"
    t.string "resource_id"
    t.string "effect", null: false
    t.json "constraints", default: [], null: false
    t.datetime "expires_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id", "principal_type", "principal_id", "action", "resource_type"], name: "idx_acting_for_delegations_authorization_lookup"
    t.index ["agent_id"], name: "index_acting_for_delegations_on_agent_id"
    t.check_constraint "effect::text = ANY (ARRAY['allow'::character varying::text, 'require_approval'::character varying::text])", name: "chk_acting_for_delegations_effect"
    t.check_constraint "resource_type IS NOT NULL OR resource_id IS NULL", name: "chk_acting_for_delegations_resource_scope"
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.integer "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "purchases", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.integer "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source", default: "shopping_agent", null: false
    t.index ["product_id"], name: "index_purchases_on_product_id"
    t.index ["user_id"], name: "index_purchases_on_user_id"
    t.check_constraint "source::text = ANY (ARRAY['human'::character varying, 'shopping_agent'::character varying]::text[])", name: "chk_purchases_source"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "acting_for_delegations", "acting_for_agents", column: "agent_id"
  add_foreign_key "purchases", "products"
  add_foreign_key "purchases", "users"
end
