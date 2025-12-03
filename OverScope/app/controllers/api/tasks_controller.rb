require 'ostruct'

module Api
  class TasksController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :require_organization

    def score
      task_ids = params[:task_ids] || []
      
      tasks = current_organization.projects
        .joins(:tasks)
        .where(tasks: { id: task_ids })
        .select('tasks.id, tasks.priority, tasks.due_date, tasks.status, tasks.complexity, tasks.estimate_hours')

      task_data = tasks.map do |task|
        {
          id: task.id,
          complexity: task.complexity || 3,
          due_date: task.due_date&.iso8601,
          priority: task.priority,
          status: task.status
        }
      end

      scored_tasks = ScalaTaskEngineClient.new.score_tasks(task_data)

      render json: scored_tasks
    end

    def estimate
      # For new tasks, use params; for existing tasks, fetch from DB
      if params[:task_id] && params[:task_id] != 'new'
        task = current_organization.projects
          .joins(:tasks)
          .where(tasks: { id: params[:task_id] })
          .select('tasks.*')
          .first

        unless task
          render json: { error: 'Task not found' }, status: :not_found
          return
        end
      else
        # Create a temporary task object from params
        task = OpenStruct.new(
          id: 'new',
          priority: params[:priority]&.to_i || 3,
          due_date: params[:due_date] ? Date.parse(params[:due_date]) : nil,
          status: params[:status] || 'open',
          complexity: params[:complexity]&.to_i || 3,
          estimate_hours: params[:estimate_hours]&.to_i
        )
      end

      client = ScalaTaskEngineClient.new
      result = client.estimate_task(task, user_id: current_user&.id)

      Rails.logger.info "Estimation result: #{result.inspect}"
      render json: result
    end

    def estimation_stats
      client = ScalaTaskEngineClient.new
      stats = client.get_estimation_stats(
        user_id: params[:user_id],
        organization_id: current_organization.id
      )

      render json: stats
    end
  end
end

