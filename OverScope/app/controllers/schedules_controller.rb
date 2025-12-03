class SchedulesController < ApplicationController
  before_action :require_organization

  def index
    @client = ScalaTaskEngineClient.new
    @organization = current_organization

    # Get optimized schedule from Scala
    @optimized_schedule = get_optimized_schedule

    # Get users and their tasks
    @users = current_organization.users.includes(:memberships)
    
    # Build weekly schedule view
    @weekly_schedule = build_weekly_schedule
  end

  private

  def get_optimized_schedule
    users = current_organization.users.map do |user|
      metrics = @client.get_user_metrics(user.id.to_s)
      {
        id: user.id.to_s,
        capacityHours: metrics['capacityHours'] || 40
      }
    end

    tasks = current_organization.projects
      .joins(:tasks)
      .where(tasks: { status: ['open', 'in_progress'] })
      .select('tasks.id, tasks.estimate_hours, tasks.priority, tasks.due_date, tasks.status, tasks.title')
      .map do |task|
        {
          id: task.id.to_s,
          estimateHours: task.estimate_hours || 8,
          priority: task.priority,
          dueDate: task.due_date&.iso8601,
          status: task.status,
          title: task.title
        }
      end

    @client.optimize_schedule(users: users, tasks: tasks)
  rescue => e
    Rails.logger.error "Error getting optimized schedule: #{e.message}"
    { 'assignments' => [], 'score' => 0 }
  end

  def build_weekly_schedule
    # Group tasks by week and user
    week_start = Date.today.beginning_of_week
    
    schedule = {}
    
    current_organization.projects.joins(:tasks).where(tasks: { status: ['open', 'in_progress'] }).each do |project|
      project.tasks.each do |task|
        week_key = task.due_date&.beginning_of_week || week_start
        
        schedule[week_key] ||= {}
        schedule[week_key][:tasks] ||= []
        schedule[week_key][:tasks] << task
      end
    end

    schedule
  end
end

