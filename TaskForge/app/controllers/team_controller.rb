class TeamController < ApplicationController
  before_action :require_organization

  def index
    @users = current_organization.users.includes(:memberships)
    @client = ScalaTaskEngineClient.new

    # Get metrics for each user
    @user_data = @users.map do |user|
      metrics = @client.get_user_metrics(user.id.to_s)
      
      # Get user's tasks
      user_tasks = current_organization.projects
        .joins(:tasks)
        .where(tasks: { status: ['open', 'in_progress'] })
        .select('tasks.*')
        # In real app, filter by assignment

      {
        user: user,
        metrics: metrics,
        tasks_count: user_tasks.count,
        completed_last_30_days: metrics['tasksCompletedLast30Days'] || 0,
        avg_completion_hours: metrics['avgCompletionHours'] || 0,
        current_load: metrics['currentLoadHours'] || 0,
        capacity: metrics['capacityHours'] || 40
      }
    end
  end
end

