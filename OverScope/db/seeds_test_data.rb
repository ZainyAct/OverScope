# Test Data Seed File
# This creates realistic historical data for testing Scala features
# Run with: rails db:seed:replant SEED_FILE=db/seeds_test_data.rb
# Or: rails runner db/seeds_test_data.rb

require 'bcrypt'

puts "🌱 Seeding test data for Scala features..."

# Helper to generate timestamps
def days_ago(days)
  days.days.ago
end

def weeks_ago(weeks)
  weeks.weeks.ago
end

# Create organization
org = Organization.find_or_create_by!(name: "Acme Software Inc.") do |o|
  o.created_at = 6.months.ago
  o.updated_at = 6.months.ago
end
puts "✓ Organization: #{org.name}"

# Create users with realistic names and emails
users_data = [
  { email: "alice@acme.com", full_name: "Alice Johnson", capacity: 40 },
  { email: "bob@acme.com", full_name: "Bob Smith", capacity: 35 },
  { email: "charlie@acme.com", full_name: "Charlie Brown", capacity: 30 },
  { email: "diana@acme.com", full_name: "Diana Prince", capacity: 25 },
  { email: "eve@acme.com", full_name: "Eve Williams", capacity: 20 }
]

users = users_data.map do |user_data|
  user = User.find_or_initialize_by(email: user_data[:email])
  if user.new_record?
    user.full_name = user_data[:full_name]
    user.password = "password123"
    user.password_confirmation = "password123"
    user.created_at = 5.months.ago
    user.updated_at = 5.months.ago
    user.save!
  end
  
  # Create membership
  Membership.find_or_create_by!(user: user, organization: org) do |m|
    m.role = user.email == "alice@acme.com" ? "admin" : "member"
    m.created_at = 5.months.ago
    m.updated_at = 5.months.ago
  end
  
  puts "✓ User: #{user.full_name} (#{user.email})"
  user
end

# Create projects
projects_data = [
  { name: "Website Redesign", description: "Complete redesign of company website" },
  { name: "Mobile App", description: "iOS and Android mobile application" },
  { name: "API Development", description: "RESTful API for third-party integrations" },
  { name: "Data Migration", description: "Migrate legacy data to new system" },
  { name: "Security Audit", description: "Comprehensive security review" }
]

projects = projects_data.map do |proj_data|
  project = Project.find_or_create_by!(name: proj_data[:name], organization: org) do |p|
    p.description = proj_data[:description]
    p.created_at = 4.months.ago
    p.updated_at = 4.months.ago
  end
  puts "✓ Project: #{project.name}"
  project
end

# Create tasks with various statuses, priorities, and due dates
puts "\n📋 Creating tasks..."

# Completed tasks (historical data for analytics)
completed_tasks = []
30.times do |i|
  project = projects.sample
  user = users.sample
  created_at = days_ago(60 - (i * 2))
  started_at = created_at + rand(1..3).days
  completed_at = started_at + rand(2..10).days
  
  task = Task.create!(
    project: project,
    title: "Completed Task #{i + 1}: #{['Fix bug', 'Implement feature', 'Write tests', 'Code review', 'Update docs'].sample}",
    description: "This task was completed #{((Time.now - completed_at) / 1.day).to_i} days ago",
    priority: rand(1..5),
    status: "completed",
    due_date: completed_at + rand(-2..5).days,
    complexity: rand(1..5),
    estimate_hours: [2, 4, 8, 16, 32][rand(0..4)],
    created_at: created_at,
    updated_at: completed_at
  )
  
  # Create task events
  TaskEvent.create!(
    task: task,
    event_type: "created",
    actor_user_id: user.id,
    created_at: created_at,
    updated_at: created_at
  )
  
  TaskEvent.create!(
    task: task,
    event_type: "started",
    actor_user_id: user.id,
    created_at: started_at,
    updated_at: started_at
  )
  
  TaskEvent.create!(
    task: task,
    event_type: "completed",
    actor_user_id: user.id,
    created_at: completed_at,
    updated_at: completed_at
  )
  
  completed_tasks << task
end

# In-progress tasks
in_progress_tasks = []
15.times do |i|
  project = projects.sample
  user = users.sample
  created_at = days_ago(rand(1..30))
  started_at = created_at + rand(0..2).days
  
  task = Task.create!(
    project: project,
    title: "In Progress Task #{i + 1}: #{['Refactor code', 'Add tests', 'Fix issue', 'Optimize query', 'Design UI'].sample}",
    description: "Currently being worked on",
    priority: rand(2..5),
    status: "in_progress",
    due_date: Date.today + rand(1..14).days,
    complexity: rand(1..5),
    estimate_hours: [2, 4, 8, 16, 32][rand(0..4)],
    created_at: created_at,
    updated_at: started_at
  )
  
  TaskEvent.create!(
    task: task,
    event_type: "created",
    actor_user_id: user.id,
    created_at: created_at,
    updated_at: created_at
  )
  
  TaskEvent.create!(
    task: task,
    event_type: "started",
    actor_user_id: user.id,
    created_at: started_at,
    updated_at: started_at
  )
  
  in_progress_tasks << task
end

# Open tasks (various priorities and due dates)
open_tasks = []
40.times do |i|
  project = projects.sample
  user = users.sample
  created_at = days_ago(rand(1..45))
  
  # Mix of overdue, due soon, and future tasks
  days_from_now = case rand(1..10)
  when 1..2 then rand(-10..-1)  # Overdue
  when 3..5 then rand(0..3)      # Due soon
  else rand(4..30)               # Future
  end
  
  task = Task.create!(
    project: project,
    title: "Open Task #{i + 1}: #{['New feature', 'Bug fix', 'Enhancement', 'Research', 'Documentation'].sample}",
    description: "Task waiting to be started",
    priority: rand(1..5),
    status: "open",
    due_date: Date.today + days_from_now.days,
    complexity: rand(1..5),
    estimate_hours: [2, 4, 8, 16, 32][rand(0..4)],
    created_at: created_at,
    updated_at: created_at
  )
  
  TaskEvent.create!(
    task: task,
    event_type: "created",
    actor_user_id: user.id,
    created_at: created_at,
    updated_at: created_at
  )
  
  open_tasks << task
end

# Some reassigned tasks
5.times do |i|
  task = in_progress_tasks.sample
  old_user = users.sample
  new_user = (users - [old_user]).sample
  
  TaskEvent.create!(
    task: task,
    event_type: "reassigned",
    actor_user_id: old_user.id,
    metadata: { "from_user_id" => old_user.id.to_s, "to_user_id" => new_user.id.to_s },
    created_at: days_ago(rand(1..10)),
    updated_at: days_ago(rand(1..10))
  )
end

# Create some high-priority, overdue tasks for testing optimizer
5.times do |i|
  project = projects.sample
  user = users.sample
  
  task = Task.create!(
    project: project,
    title: "URGENT: Critical Task #{i + 1}",
    description: "This is a high-priority overdue task",
    priority: 5,
    status: "open",
    due_date: Date.today - rand(1..7).days,  # Overdue
    complexity: rand(3..5),  # Urgent tasks are usually complex
    estimate_hours: [8, 16, 32][rand(0..2)],
    created_at: days_ago(rand(5..15)),
    updated_at: days_ago(rand(5..15))
  )
  
  TaskEvent.create!(
    task: task,
    event_type: "created",
    actor_user_id: user.id,
    created_at: task.created_at,
    updated_at: task.created_at
  )
end

# Create task_metrics_daily for the last 60 days
puts "\n📊 Creating daily metrics..."
60.times do |i|
  date = Date.today - i.days
  
  # Count tasks created and completed on this day (for this org)
  tasks_created = Task.joins(:project)
    .where(projects: { organization_id: org.id })
    .where("DATE(tasks.created_at) = ?", date)
    .count
  
  tasks_completed = Task.joins(:project, :task_events)
    .where(projects: { organization_id: org.id })
    .where("task_events.event_type = ? AND DATE(task_events.created_at) = ?", "completed", date)
    .distinct
    .count
  
  # Calculate average lead time for tasks completed on this day (for this org)
  completed_tasks_today = Task.joins(:project, :task_events)
    .where(projects: { organization_id: org.id })
    .where("task_events.event_type = ? AND DATE(task_events.created_at) = ?", "completed", date)
    .distinct
  
  avg_lead_time = if completed_tasks_today.any?
    lead_times = completed_tasks_today.map do |t|
      created_event = t.task_events.where(event_type: "created").order(:created_at).first
      completed_event = t.task_events.where(event_type: "completed").order(:created_at).first
      if created_event && completed_event
        (completed_event.created_at - t.created_at) / 3600.0
      end
    end.compact
    
    avg_lead_time = lead_times.any? ? lead_times.sum / lead_times.length : nil
  else
    nil
  end
  
  # Count open tasks at end of day (tasks in this org's projects)
  open_tasks_count = Task.joins(:project)
    .where(projects: { organization_id: org.id })
    .where("tasks.status IN (?) AND tasks.created_at <= ?", ["open", "in_progress"], date.end_of_day)
    .count
  
  TaskMetricsDaily.upsert(
    {
      organization_id: org.id,
      date: date,
      tasks_created: tasks_created,
      tasks_completed: tasks_completed,
      avg_lead_time_hours: avg_lead_time,
      open_tasks_end_of_day: open_tasks_count
    },
    unique_by: [:organization_id, :date]
  )
end

puts "\n✅ Seed data created successfully!"
puts "\n📈 Summary:"
puts "  Organization: #{org.name} (#{org.id})"
puts "  Users: #{users.count}"
puts "  Projects: #{projects.count}"
puts "  Completed Tasks: #{completed_tasks.count}"
puts "  In Progress Tasks: #{in_progress_tasks.count}"
puts "  Open Tasks: #{open_tasks.count}"
puts "  Total Tasks: #{Task.where(project: projects).count}"
puts "  Task Events: #{TaskEvent.joins(task: { project: :organization }).where(projects: { organization_id: org.id }).count}"
puts "  Daily Metrics: #{TaskMetricsDaily.where(organization_id: org.id).count} days"
puts "\n🔑 Test Credentials:"
puts "  All users have password: password123"
users.each { |u| puts "    - #{u.email} (#{u.full_name})" }
puts "\n💡 Use this organization ID for testing: #{org.id}"

