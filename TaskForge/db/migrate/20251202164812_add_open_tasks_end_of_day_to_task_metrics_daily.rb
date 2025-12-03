class AddOpenTasksEndOfDayToTaskMetricsDaily < ActiveRecord::Migration[8.1]
  def change
    add_column :task_metrics_daily, :open_tasks_end_of_day, :integer, default: 0, null: false
  end
end

