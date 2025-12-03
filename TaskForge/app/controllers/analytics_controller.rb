class AnalyticsController < ApplicationController
  before_action :require_organization

  def index
    @client = ScalaTaskEngineClient.new
    @organization = current_organization

    # Get organization-wide metrics
    @users = current_organization.users.includes(:memberships)
    
    # Get user metrics
    @user_metrics = @users.map do |user|
      metrics = @client.get_user_metrics(user.id.to_s)
      [user, metrics]
    end.to_h

    # Get pressure alerts
    @pressure_alerts = @client.get_pressure_alerts(threshold: 0.7)

    # Get fire alarm status
    @fire_alarm = @client.check_fire_alarm(current_organization.id.to_s)

    # Get estimation stats
    @estimation_stats = @client.get_estimation_stats(organization_id: current_organization.id.to_s)

    # Calculate completion velocity (tasks completed in last 30 days)
    @completion_velocity = calculate_completion_velocity

    # Calculate productivity metrics
    @productivity_metrics = calculate_productivity_metrics
  end

  private

  def calculate_completion_velocity
    completed_tasks = current_organization.projects
      .joins(:tasks)
      .where(tasks: { status: 'completed' })
      .where('tasks.updated_at > ?', 30.days.ago)
      .count('tasks.id')

    {
      tasks_completed: completed_tasks,
      daily_average: completed_tasks / 30.0,
      trend: 'stable' # Could calculate from historical data
    }
  end

  def calculate_productivity_metrics
    # Get tasks directly using the for_organization scope
    tasks_relation = Task.for_organization(current_organization)
    
    {
      total_tasks: tasks_relation.count,
      completed_tasks: tasks_relation.where(status: 'completed').count,
      in_progress_tasks: tasks_relation.where(status: 'in_progress').count,
      open_tasks: tasks_relation.where(status: 'open').count,
      avg_completion_time: calculate_avg_completion_time(tasks_relation),
      overdue_tasks: tasks_relation.where('tasks.due_date < ? AND tasks.status != ?', Date.today, 'completed').count
    }
  end

  def calculate_avg_completion_time(tasks_relation)
    completed_tasks = tasks_relation.where(status: 'completed').includes(:task_events).to_a
    return 0 if completed_tasks.empty?

    total_hours = completed_tasks.sum do |task|
      task.lead_time_hours || 0
    end

    total_hours / completed_tasks.count.to_f
  end
end

