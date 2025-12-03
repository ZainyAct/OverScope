class ScalaTaskEngineClient
  BASE_URL = ENV.fetch('SCALA_TASK_ENGINE_URL', 'http://scala-task-engine:8080')

  def score_tasks(tasks)
    response = connection.post('/score-tasks') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = tasks.to_json
    end

    response.body
  rescue Faraday::Error => e
    Rails.logger.error "Error calling Scala service: #{e.message}"
    []
  end

  def estimate_task(task, user_id: nil)
    task_data = {
      id: task.id,
      estimateHours: task.estimate_hours || 5,
      priority: task.priority,
      dueDate: task.due_date&.iso8601,
      status: task.status,
      complexity: task.complexity || 3,
      tags: []
    }

    request_data = {
      task: task_data,
      userId: user_id
    }

    response = connection.post('/estimate') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = request_data.to_json
    end

    response.body
  rescue Faraday::Error => e
    Rails.logger.error "Error calling estimation service: #{e.message}"
    { 'estimateHours' => 8, 'method' => 'fallback', 'breakdown' => {} }
  end

  def track_estimation_accuracy(task_id, estimated_hours, actual_hours, user_id: nil)
    request_data = {
      taskId: task_id,
      estimatedHours: estimated_hours,
      actualHours: actual_hours,
      userId: user_id
    }

    response = connection.post('/estimate/track-accuracy') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = request_data.to_json
    end

    response.body
  rescue Faraday::Error => e
    Rails.logger.error "Error tracking estimation accuracy: #{e.message}"
    { 'status' => 'error' }
  end

  def get_estimation_stats(user_id: nil, organization_id: nil)
    params = {}
    params[:userId] = user_id if user_id
    params[:organizationId] = organization_id if organization_id

    response = connection.get('/estimate/stats', params)

    response.body
  rescue Faraday::Error => e
    Rails.logger.error "Error getting estimation stats: #{e.message}"
    {
      'totalTasks' => 0,
      'avgAccuracy' => 0.0,
      'avgOverestimate' => 0.0,
      'avgUnderestimate' => 0.0
    }
  end

  # Analytics endpoints
  def get_user_metrics(user_id)
    response = connection.get("/analytics/user/#{user_id}")
    response.body
  rescue Faraday::Error => e
    Rails.logger.error "Error getting user metrics: #{e.message}"
    {}
  end

  def get_pressure_alerts(threshold: 0.7)
    response = connection.get('/analytics/alerts', { threshold: threshold })
    response.body
  rescue Faraday::Error => e
    Rails.logger.error "Error getting pressure alerts: #{e.message}"
    []
  end

  def check_fire_alarm(organization_id, threshold: 5, hours_window: 24)
    response = connection.get('/analytics/fire-alarm', {
      organizationId: organization_id,
      threshold: threshold,
      hoursWindow: hours_window
    })
    response.body
  rescue Faraday::Error => e
    Rails.logger.error "Error checking fire alarm: #{e.message}"
    { 'alert' => false, 'message' => 'Service unavailable' }
  end

  # Forecasting endpoints
  def forecast(users:, tasks: [], organization_id: nil)
    request_data = {
      users: users,
      tasks: tasks,
      organizationId: organization_id
    }

    response = connection.post('/forecast') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = request_data.to_json
    end

    response.body
  rescue Faraday::Error => e
    Rails.logger.error "Error forecasting: #{e.message}"
    []
  end

  def detect_burnout_risk(threshold: 0.8, organization_id: nil)
    params = { threshold: threshold }
    params[:organizationId] = organization_id if organization_id

    response = connection.get('/forecast/burnout', params)
    response.body
  rescue Faraday::Error => e
    Rails.logger.error "Error detecting burnout risk: #{e.message}"
    []
  end

  # Schedule optimization
  def optimize_schedule(users:, tasks:)
    request_data = {
      users: users,
      tasks: tasks
    }

    response = connection.post('/optimize-schedule') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = request_data.to_json
    end

    response.body
  rescue Faraday::Error => e
    Rails.logger.error "Error optimizing schedule: #{e.message}"
    { 'assignments' => [], 'score' => 0 }
  end

  # Simulation
  def simulate(users:, tasks: [], config: {})
    request_data = {
      users: users,
      tasks: tasks,
      config: config
    }

    response = connection.post('/simulate') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = request_data.to_json
    end

    response.body
  rescue Faraday::Error => e
    Rails.logger.error "Error running simulation: #{e.message}"
    { 'successRate' => 0, 'weeksToComplete' => 0, 'summary' => {} }
  end

  # Priority calculation
  def calculate_priority(task)
    request_data = {
      task: {
        id: task.id.to_s,
        estimateHours: task.estimate_hours || 5,
        priority: task.priority,
        dueDate: task.due_date&.iso8601,
        status: task.status,
        complexity: task.complexity || 3,
        tags: []
      }
    }

    response = connection.post('/priority/calculate') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = request_data.to_json
    end

    response.body
  rescue Faraday::Error => e
    Rails.logger.error "Error calculating priority: #{e.message}"
    { 'score' => task.priority, 'explanations' => [] }
  end

  private

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |conn|
      conn.request :json
      conn.response :json
      conn.adapter Faraday.default_adapter
    end
  end
end

