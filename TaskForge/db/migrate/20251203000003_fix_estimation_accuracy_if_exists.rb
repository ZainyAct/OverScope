# Migration to fix estimation_accuracy table if it was created by Scala service
class FixEstimationAccuracyIfExists < ActiveRecord::Migration[8.1]
  def up
    if table_exists?(:estimation_accuracy)
      # Ensure all columns exist
      add_column :estimation_accuracy, :estimated_hours, :integer, null: false, default: 0 unless column_exists?(:estimation_accuracy, :estimated_hours)
      add_column :estimation_accuracy, :actual_hours, :decimal, null: false, default: 0 unless column_exists?(:estimation_accuracy, :actual_hours)
      add_column :estimation_accuracy, :accuracy_ratio, :decimal, null: false, default: 1.0 unless column_exists?(:estimation_accuracy, :accuracy_ratio)
      add_column :estimation_accuracy, :user_id, :uuid unless column_exists?(:estimation_accuracy, :user_id)
      add_column :estimation_accuracy, :created_at, :datetime unless column_exists?(:estimation_accuracy, :created_at)
      add_column :estimation_accuracy, :updated_at, :datetime unless column_exists?(:estimation_accuracy, :updated_at)
      
      # Add foreign key if it doesn't exist
      unless foreign_key_exists?(:estimation_accuracy, :tasks)
        add_foreign_key :estimation_accuracy, :tasks, type: :uuid
      end
      
      # Add indexes if they don't exist
      add_index :estimation_accuracy, :task_id unless index_exists?(:estimation_accuracy, :task_id)
      add_index :estimation_accuracy, :user_id unless index_exists?(:estimation_accuracy, :user_id)
      add_index :estimation_accuracy, :created_at unless index_exists?(:estimation_accuracy, :created_at)
    end
  end

  def down
    # No-op - don't remove columns that might be needed
  end
end

