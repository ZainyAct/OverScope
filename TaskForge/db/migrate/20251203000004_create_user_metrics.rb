class CreateUserMetrics < ActiveRecord::Migration[8.1]
  def up
    # Table might already exist (created by Scala service), so handle gracefully
    return if table_exists?(:user_metrics)
    
    # Table doesn't exist, create it
    create_table :user_metrics, id: false, primary_key: :user_id do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, primary_key: true
      t.decimal :avg_completion_hours, default: 0
      t.integer :tasks_completed_last_30_days, default: 0
      t.decimal :current_load_hours, default: 0
      t.integer :capacity_hours, default: 40
      t.decimal :pressure_score, default: 0
      t.timestamps
    end
  end

  def down
    drop_table :user_metrics if table_exists?(:user_metrics)
  end
end

