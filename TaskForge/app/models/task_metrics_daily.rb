class TaskMetricsDaily < ApplicationRecord
  self.table_name = 'task_metrics_daily'
  self.primary_key = [:organization_id, :date]

  belongs_to :organization

  validates :date, presence: true
  validates :tasks_created, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :tasks_completed, presence: true, numericality: { greater_than_or_equal_to: 0 }
end

