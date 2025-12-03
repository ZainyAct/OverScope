class CreateTaskEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :task_events, id: :uuid do |t|
      t.references :task, null: false, foreign_key: true, type: :uuid
      t.string :event_type, null: false
      t.references :actor_user, null: true, foreign_key: { to_table: :users }, type: :uuid
      t.jsonb :metadata

      t.timestamps
    end

    add_index :task_events, [:task_id, :created_at]
  end
end

