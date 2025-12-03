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

ActiveRecord::Schema[8.1].define(version: 2025_12_03_000006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "estimation_accuracy", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "accuracy_ratio", null: false
    t.decimal "actual_hours", null: false
    t.datetime "created_at", precision: nil, default: -> { "now()" }
    t.integer "estimated_hours", null: false
    t.uuid "task_id", null: false
    t.datetime "updated_at", precision: nil, default: -> { "now()" }
    t.uuid "user_id"
    t.index ["created_at"], name: "index_estimation_accuracy_on_created_at"
    t.index ["task_id"], name: "index_estimation_accuracy_on_task_id"
    t.index ["user_id"], name: "index_estimation_accuracy_on_user_id"
  end

  create_table "invoices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "amount_cents"
    t.date "billing_date"
    t.datetime "created_at", null: false
    t.string "currency", default: "usd"
    t.uuid "organization_id", null: false
    t.string "status"
    t.string "stripe_invoice_id"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "billing_date"], name: "index_invoices_on_organization_id_and_billing_date"
    t.index ["organization_id"], name: "index_invoices_on_organization_id"
  end

  create_table "memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "organization_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["user_id", "organization_id"], name: "index_memberships_on_user_id_and_organization_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "projects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.uuid "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_projects_on_organization_id"
  end

  create_table "subscriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "current_period_end", precision: nil
    t.uuid "organization_id", null: false
    t.string "status", default: "incomplete"
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_subscriptions_on_organization_id"
  end

  create_table "task_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "actor_user_id"
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.jsonb "metadata"
    t.uuid "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_user_id"], name: "index_task_events_on_actor_user_id"
    t.index ["task_id", "created_at"], name: "index_task_events_on_task_id_and_created_at"
    t.index ["task_id"], name: "index_task_events_on_task_id"
  end

  create_table "task_metrics_daily", id: false, force: :cascade do |t|
    t.decimal "avg_lead_time_hours"
    t.date "date", null: false
    t.integer "open_tasks_end_of_day", default: 0, null: false
    t.uuid "organization_id", null: false
    t.integer "tasks_completed", default: 0, null: false
    t.integer "tasks_created", default: 0, null: false
    t.index ["organization_id", "date"], name: "index_task_metrics_daily_on_organization_id_and_date", unique: true
    t.index ["organization_id"], name: "index_task_metrics_daily_on_organization_id"
  end

  create_table "tasks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "complexity", default: 3
    t.datetime "created_at", null: false
    t.text "description"
    t.date "due_date"
    t.integer "estimate_hours", default: 5
    t.integer "priority", default: 3
    t.uuid "project_id", null: false
    t.string "status", default: "open"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "status", "due_date"], name: "index_tasks_on_project_id_and_status_and_due_date"
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.check_constraint "complexity >= 1 AND complexity <= 5", name: "tasks_complexity_check"
    t.check_constraint "estimate_hours > 0", name: "tasks_estimate_hours_check"
    t.check_constraint "priority >= 1 AND priority <= 5", name: "tasks_priority_check"
  end

  create_table "user_metrics", primary_key: "user_id", id: :uuid, default: nil, force: :cascade do |t|
    t.decimal "avg_completion_hours"
    t.integer "capacity_hours", default: 40
    t.datetime "created_at"
    t.decimal "current_load_hours", default: "0.0"
    t.decimal "pressure_score"
    t.integer "tasks_completed_last_30_days", default: 0
    t.datetime "updated_at", precision: nil, default: -> { "now()" }
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "full_name"
    t.datetime "remember_created_at"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "estimation_accuracy", "tasks", name: "estimation_accuracy_task_id_fkey"
  add_foreign_key "invoices", "organizations"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "projects", "organizations"
  add_foreign_key "subscriptions", "organizations"
  add_foreign_key "task_events", "tasks"
  add_foreign_key "task_events", "users", column: "actor_user_id"
  add_foreign_key "task_metrics_daily", "organizations"
  add_foreign_key "tasks", "projects"
end
