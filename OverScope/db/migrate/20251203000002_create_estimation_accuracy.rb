class CreateEstimationAccuracy < ActiveRecord::Migration[8.1]
  def up
    # Table might already exist (created by Scala service), so handle gracefully
    return if table_exists?(:estimation_accuracy)
    
    # Table doesn't exist, create it
    create_table :estimation_accuracy, id: :uuid do |t|
      t.references :task, null: false, foreign_key: true, type: :uuid
      t.integer :estimated_hours, null: false
      t.decimal :actual_hours, null: false
      t.decimal :accuracy_ratio, null: false # actual / estimated
      t.uuid :user_id # The user who completed the task
      t.timestamps
    end

    add_index :estimation_accuracy, :task_id
    add_index :estimation_accuracy, :user_id
    add_index :estimation_accuracy, :created_at
  end

  def down
    drop_table :estimation_accuracy if table_exists?(:estimation_accuracy)
  end
end

