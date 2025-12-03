class CreateTaskMetricsDaily < ActiveRecord::Migration[8.1]
  def change
    create_table :task_metrics_daily, id: false do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.date :date, null: false
      t.integer :tasks_created, null: false, default: 0
      t.integer :tasks_completed, null: false, default: 0
      t.numeric :avg_lead_time_hours
    end

    add_index :task_metrics_daily, [:organization_id, :date], unique: true
  end
end

