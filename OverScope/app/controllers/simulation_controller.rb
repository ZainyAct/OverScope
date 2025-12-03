class SimulationController < ApplicationController
  before_action :require_organization

  def index
    @client = ScalaTaskEngineClient.new
    @organization = current_organization
    @users = current_organization.users.includes(:memberships)

    # Default simulation config
    @default_config = {
      weeks: 4,
      newUserCapacity: 0,
      dropLowPriority: false
    }

    # Run simulation if params provided
    if params[:run_simulation] == 'true'
      @simulation_result = run_simulation
    end
  end

  def create
    @client = ScalaTaskEngineClient.new
    
    users = current_organization.users.map do |user|
      metrics = @client.get_user_metrics(user.id.to_s)
      {
        id: user.id.to_s,
        capacityHours: metrics['capacityHours'] || 40
      }
    end

    # Add new user if specified
    if params[:new_user_capacity].to_i > 0
      users << {
        id: "new-user-#{Time.now.to_i}",
        capacityHours: params[:new_user_capacity].to_i
      }
    end

    tasks = current_organization.projects
      .joins(:tasks)
      .where(tasks: { status: ['open', 'in_progress'] })
      .select('tasks.id, tasks.estimate_hours, tasks.priority, tasks.due_date, tasks.status, tasks.title')

    # Filter out low priority if requested
    if params[:drop_low_priority] == 'true'
      tasks = tasks.where('tasks.priority >= ?', 3)
    end

    tasks = tasks.map do |task|
      {
        id: task.id.to_s,
        estimateHours: task.estimate_hours || 8,
        priority: task.priority,
        dueDate: task.due_date&.iso8601,
        status: task.status,
        title: task.title
      }
    end

    config = {
      weeks: params[:weeks].to_i || 4,
      newUserCapacity: params[:new_user_capacity].to_i || 0,
      dropLowPriority: params[:drop_low_priority] == 'true'
    }

    result = @client.simulate(users: users, tasks: tasks, config: config)

    render json: result
  rescue => e
    Rails.logger.error "Error running simulation: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def run_simulation
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

    @client.simulate(users: users, tasks: tasks, config: @default_config)
  rescue => e
    Rails.logger.error "Error running simulation: #{e.message}"
    nil
  end
end

