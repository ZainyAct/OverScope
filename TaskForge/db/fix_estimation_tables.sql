-- Fix estimation_accuracy table if it was created by Scala service
-- Run this if migration fails due to table already existing

-- Ensure all columns exist
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

-- Add foreign key if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'estimation_accuracy_task_id_fk'
  ) THEN
    ALTER TABLE estimation_accuracy 
    ADD CONSTRAINT estimation_accuracy_task_id_fk 
    FOREIGN KEY (task_id) REFERENCES tasks(id);
  END IF;
END $$;

-- Add indexes if they don't exist
CREATE INDEX IF NOT EXISTS index_estimation_accuracy_on_task_id ON estimation_accuracy(task_id);
CREATE INDEX IF NOT EXISTS index_estimation_accuracy_on_user_id ON estimation_accuracy(user_id);
CREATE INDEX IF NOT EXISTS index_estimation_accuracy_on_created_at ON estimation_accuracy(created_at);

-- Fix user_metrics table if it was created by Scala service
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

-- Add foreign key for user_metrics if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'user_metrics_user_id_fk'
  ) THEN
    ALTER TABLE user_metrics 
    ADD CONSTRAINT user_metrics_user_id_fk 
    FOREIGN KEY (user_id) REFERENCES users(id);
  END IF;
END $$;

