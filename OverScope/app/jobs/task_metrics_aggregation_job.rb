class TaskMetricsAggregationJob < ApplicationJob
  queue_as :default

  def perform(date = Date.yesterday)
    Organization.find_each do |org|
      metrics = org.task_metrics_daily.find_or_initialize_by(date: date)
      
      tasks_created = org.projects
        .joins(:tasks)
        .where(tasks: { created_at: date.beginning_of_day..date.end_of_day })
        .count

      completed_tasks = org.projects
        .joins(:tasks)
        .where(tasks: { status: 'completed' })
        .where('tasks.created_at <= ?', date.end_of_day)
        .where(
          'EXISTS (SELECT 1 FROM task_events te WHERE te.task_id = tasks.id AND te.event_type = ? AND DATE(te.created_at) = ?)',
          'completed',
          date
        )
        .count

      lead_times = org.projects
        .joins(:tasks)
        .joins("INNER JOIN task_events te ON te.task_id = tasks.id AND te.event_type = 'completed'")
        .where('DATE(te.created_at) = ?', date)
        .where(tasks: { status: 'completed' })
        .select('EXTRACT(EPOCH FROM (te.created_at - tasks.created_at)) / 3600.0 as lead_time_hours')
        .map(&:lead_time_hours)
        .compact

      avg_lead_time = lead_times.any? ? (lead_times.sum / lead_times.size) : nil

      # Calculate open tasks at end of day (tasks created before or on this date that are still open or in_progress)
      open_tasks_end_of_day = org.projects
        .joins(:tasks)
        .where('tasks.created_at <= ?', date.end_of_day)
        .where(tasks: { status: ['open', 'in_progress'] })
        .count

      metrics.update!(
        tasks_created: tasks_created,
        tasks_completed: completed_tasks,
        avg_lead_time_hours: avg_lead_time,
        open_tasks_end_of_day: open_tasks_end_of_day
      )
    end
  end
end

