class TasksController < ApplicationController
  before_action :require_organization
  before_action :set_project, only: [:index, :new, :create]
  before_action :set_task, only: [:show, :edit, :update, :destroy]

  def index
    @tasks = @project.tasks.order(created_at: :desc)
    
    if params[:with_urgency]
      @tasks = @tasks.joins("INNER JOIN task_urgency tu ON tu.id = tasks.id")
                     .select("tasks.*, tu.urgency_rank")
                     .order("tu.urgency_rank ASC")
    end

    respond_to do |format|
      format.html
      format.json { render json: @tasks }
    end
  end

  def new
    @task = @project.tasks.build
  end

  def edit
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @task }
    end
  end

  def create
    @task = @project.tasks.build(task_params)
    
    if @task.save
      create_task_event('created')
      respond_to do |format|
        format.html { redirect_to project_tasks_path(@project), notice: 'Task created successfully' }
        format.json { render json: @task, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @task.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    old_status = @task.status
    
    if @task.update(task_params)
      if old_status != @task.status
        if @task.status == 'completed'
          create_task_event('completed')
        elsif old_status == 'completed' && @task.status != 'completed'
          create_task_event('reassigned')
        else
          create_task_event('reassigned')
        end
      end
      respond_to do |format|
        format.html { redirect_to project_task_path(@project, @task), notice: 'Task updated successfully' }
        format.json { render json: @task }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @task.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @task.destroy
    respond_to do |format|
      format.html { redirect_to project_tasks_path(@project), notice: 'Task deleted successfully' }
      format.json { head :no_content }
    end
  end


  private

  def set_project
    @project = current_organization.projects.find(params[:project_id])
  end

  def set_task
    @project = current_organization.projects.find(params[:project_id])
    @task = @project.tasks.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :description, :status, :priority, :due_date, :estimate_hours, :complexity)
  end

  def create_task_event(event_type)
    TaskEvent.create!(
      task: @task,
      event_type: event_type,
      actor_user: current_user,
      metadata: {}
    )
  end
end

