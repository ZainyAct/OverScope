class WorkloadController < ApplicationController
  before_action :require_organization

  def index
    @client = ScalaTaskEngineClient.new
    @organization = current_organization

    # Get all users in organization
    @users = current_organization.users.includes(:memberships)

    # Get workload data for each user
    @workload_data = @users.map do |user|
      metrics = @client.get_user_metrics(user.id.to_s)
      
      # Get user's assigned tasks
      assigned_tasks = current_organization.projects
        .joins(:tasks)
        .where(tasks: { status: ['open', 'in_progress'] })
        .select('tasks.*')
        # In a real app, you'd have an assignments table
      # For now, we'll estimate based on user metrics

      current_load = metrics['currentLoadHours'] || 0
      capacity = metrics['capacityHours'] || 40
      utilization = capacity > 0 ? (current_load / capacity.to_f * 100) : 0

      {
        user: user,
        metrics: metrics,
        current_load_hours: current_load,
        capacity_hours: capacity,
        utilization_percent: utilization,
        status: utilization_status(utilization),
        tasks_count: assigned_tasks.count
      }
    end

    # Get suggested workload from Scala optimizer
    @suggested_workload = get_suggested_workload
  end

  private

  def utilization_status(utilization)
    case utilization
    when 0..50 then 'underutilized'
    when 50..85 then 'optimal'
    when 85..100 then 'high'
    else 'overloaded'
    end
  end

  def get_suggested_workload
    users = @users.map do |user|
      metrics = @client.get_user_metrics(user.id.to_s)
      {
        id: user.id.to_s,
        capacityHours: metrics['capacityHours'] || 40
      }
    end

    tasks = current_organization.projects
      .joins(:tasks)
      .where(tasks: { status: ['open', 'in_progress'] })
      .select('tasks.id, tasks.estimate_hours, tasks.priority, tasks.due_date, tasks.status')
      .map do |task|
        {
          id: task.id.to_s,
          estimateHours: task.estimate_hours || 8,
          priority: task.priority,
          dueDate: task.due_date&.iso8601,
          status: task.status
        }
      end

    @client.optimize_schedule(users: users, tasks: tasks)
  rescue => e
    Rails.logger.error "Error getting suggested workload: #{e.message}"
    { 'assignments' => [], 'score' => 0 }
  end
end

