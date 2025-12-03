# Migration to ensure estimation tables have all required columns
# This handles the case where tables were created by Scala service
class EnsureEstimationTablesStructure < ActiveRecord::Migration[8.1]
  def up
    # Fix estimation_accuracy table if it exists but is missing columns
    if table_exists?(:estimation_accuracy)
      execute <<-SQL
        DO $$ 
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'estimation_accuracy' AND column_name = 'estimated_hours') THEN
            ALTER TABLE estimation_accuracy ADD COLUMN estimated_hours INTEGER NOT NULL DEFAULT 0;
          END IF;
          
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'estimation_accuracy' AND column_name = 'actual_hours') THEN
            ALTER TABLE estimation_accuracy ADD COLUMN actual_hours DECIMAL NOT NULL DEFAULT 0;
          END IF;
          
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'estimation_accuracy' AND column_name = 'accuracy_ratio') THEN
            ALTER TABLE estimation_accuracy ADD COLUMN accuracy_ratio DECIMAL NOT NULL DEFAULT 1.0;
          END IF;
          
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'estimation_accuracy' AND column_name = 'user_id') THEN
            ALTER TABLE estimation_accuracy ADD COLUMN user_id UUID;
          END IF;
          
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'estimation_accuracy' AND column_name = 'created_at') THEN
            ALTER TABLE estimation_accuracy ADD COLUMN created_at TIMESTAMP DEFAULT NOW();
          END IF;
          
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'estimation_accuracy' AND column_name = 'updated_at') THEN
            ALTER TABLE estimation_accuracy ADD COLUMN updated_at TIMESTAMP DEFAULT NOW();
          END IF;
        END $$;
      SQL
      
      # Add indexes if they don't exist
      add_index :estimation_accuracy, :task_id unless index_exists?(:estimation_accuracy, :task_id)
      add_index :estimation_accuracy, :user_id unless index_exists?(:estimation_accuracy, :user_id)
      add_index :estimation_accuracy, :created_at unless index_exists?(:estimation_accuracy, :created_at)
    end
    
    # Fix user_metrics table if it exists but is missing columns
    if table_exists?(:user_metrics)
      execute <<-SQL
        DO $$ 
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_metrics' AND column_name = 'avg_completion_hours') THEN
            ALTER TABLE user_metrics ADD COLUMN avg_completion_hours DECIMAL DEFAULT 0;
          END IF;
          
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_metrics' AND column_name = 'tasks_completed_last_30_days') THEN
            ALTER TABLE user_metrics ADD COLUMN tasks_completed_last_30_days INTEGER DEFAULT 0;
          END IF;
          
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_metrics' AND column_name = 'current_load_hours') THEN
            ALTER TABLE user_metrics ADD COLUMN current_load_hours DECIMAL DEFAULT 0;
          END IF;
          
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_metrics' AND column_name = 'capacity_hours') THEN
            ALTER TABLE user_metrics ADD COLUMN capacity_hours INTEGER DEFAULT 40;
          END IF;
          
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_metrics' AND column_name = 'pressure_score') THEN
            ALTER TABLE user_metrics ADD COLUMN pressure_score DECIMAL DEFAULT 0;
          END IF;
          
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_metrics' AND column_name = 'created_at') THEN
            ALTER TABLE user_metrics ADD COLUMN created_at TIMESTAMP DEFAULT NOW();
          END IF;
          
          IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_metrics' AND column_name = 'updated_at') THEN
            ALTER TABLE user_metrics ADD COLUMN updated_at TIMESTAMP DEFAULT NOW();
          END IF;
        END $$;
      SQL
    end
  end

  def down
    # No-op - don't remove columns
  end
end

