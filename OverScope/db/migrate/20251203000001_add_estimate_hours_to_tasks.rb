class AddEstimateHoursToTasks < ActiveRecord::Migration[8.1]
  def up
    add_column :tasks, :estimate_hours, :integer, default: 5 unless column_exists?(:tasks, :estimate_hours)
    add_column :tasks, :complexity, :integer, default: 3 unless column_exists?(:tasks, :complexity)
    
    # Add check constraints (will fail gracefully if they exist)
    begin
      add_check_constraint :tasks, "estimate_hours > 0", name: "tasks_estimate_hours_check"
    rescue ActiveRecord::StatementInvalid => e
      # Constraint might already exist, ignore
      puts "Note: estimate_hours constraint may already exist"
    end
    
    begin
      add_check_constraint :tasks, "complexity >= 1 AND complexity <= 5", name: "tasks_complexity_check"
    rescue ActiveRecord::StatementInvalid => e
      # Constraint might already exist, ignore
      puts "Note: complexity constraint may already exist"
    end
  end

  def down
    begin
      remove_check_constraint :tasks, name: "tasks_estimate_hours_check"
    rescue => e
      # Ignore if doesn't exist
    end
    
    begin
      remove_check_constraint :tasks, name: "tasks_complexity_check"
    rescue => e
      # Ignore if doesn't exist
    end
    
    remove_column :tasks, :estimate_hours if column_exists?(:tasks, :estimate_hours)
    remove_column :tasks, :complexity if column_exists?(:tasks, :complexity)
  end
end

