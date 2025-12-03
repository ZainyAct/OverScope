class ActivityController < ApplicationController
  before_action :require_organization

  def index
    # Get recent task events
    @events = current_organization.projects
      .joins(tasks: :task_events)
      .select('task_events.*, tasks.title as task_title, tasks.id as task_id, projects.name as project_name')
      .order('task_events.created_at DESC')
      .limit(100)

    # Group by date
    @events_by_date = @events.group_by { |e| e.created_at.to_date }
  end
end

