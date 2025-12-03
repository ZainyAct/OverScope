# OverScope

A task management SaaS app I built with Rails and a Scala microservice. It's basically a smarter project management tool that uses a Scala engine to help prioritize tasks, estimate work, and optimize team workloads.

## What It Is

OverScope is a multi-tenant task management platform where teams can:
- Create projects and tasks
- Get AI-powered task prioritization and estimation
- See analytics on team productivity and workload
- Run "what-if" simulations to plan better
- Track estimation accuracy over time

The cool part is the architecture: Rails handles the main app (auth, UI, database), and a separate Scala service does the heavy lifting for task scoring, workload optimization, forecasting, and simulations. They talk to each other over HTTP.

## How It Works

**Rails App** (`TaskForge/`):
- Handles all the web stuff - authentication, projects, tasks, UI
- Uses PostgreSQL for data storage
- Integrates with Stripe for billing
- Calls the Scala service when it needs smart task analysis

**Scala Service** (`backend/scala-task-engine/`):
- Runs on Akka HTTP
- Does task scoring based on priority, due dates, complexity
- Optimizes workload distribution across team members
- Forecasts capacity and burnout risk
- Runs Monte Carlo simulations for "what-if" scenarios
- Learns from historical data to improve task estimation

**Database**:
- PostgreSQL with UUIDs everywhere
- Stores tasks, projects, users, organizations
- Tracks task events for analytics
- Has views for real-time metrics

Everything runs in Docker, so setup is pretty straightforward.

## Quick Start

### Prerequisites

You'll need:
- Docker and Docker Compose installed
- Git (obviously)

### Step-by-Step Setup

1. **Clone the repo:**
   ```bash
   git clone <your-repo-url>
   cd RubyResProj
   ```

2. **Start everything with Docker Compose:**
   ```bash
   cd docker
   docker compose up --build
   ```

   This starts:
   - PostgreSQL (port 5432)
   - Redis (port 6379)
   - Rails app (port 3000)
   - Scala service (port 8080)
   - Sidekiq worker for background jobs

   The first time you run this, it'll take a few minutes to build the images and install dependencies.

3. **Run migrations:**
   
   The migrations should run automatically when Rails starts, but if you need to run them manually:
   ```bash
   docker compose exec rails-app bundle exec rails db:migrate
   ```

   If you see any errors about tables already existing (like `estimation_accuracy` or `user_metrics`), that's fine - the Scala service might have created them. The migrations are idempotent and will handle it.

4. **Seed some test data (optional):**
   ```bash
   docker compose exec rails-app bundle exec rails runner db/seeds_test_data.rb
   ```

   This creates a test organization with users and tasks so you can see the app in action.

5. **Access the app:**
   - Web UI: http://localhost:3000
   - Scala health check: http://localhost:8080/health

6. **Create your first user:**
   - Go to http://localhost:3000
   - Sign up with any email/password
   - You'll be automatically added to an organization

That's it! You should be up and running.

## Project Structure

```
RubyResProj/
├── TaskForge/              # Rails app
│   ├── app/
│   │   ├── controllers/    # All the controllers (analytics, workload, etc.)
│   │   ├── models/         # ActiveRecord models
│   │   ├── services/       # ScalaTaskEngineClient for talking to Scala
│   │   └── views/           # ERB templates
│   └── db/
│       └── migrate/         # Database migrations
│
├── backend/
│   └── scala-task-engine/  # Scala microservice
│       ├── src/main/scala/
│       └── build.sbt
│
└── docker/
    ├── docker-compose.yml  # Orchestration
    ├── Dockerfile.rails    # Rails container
    └── Dockerfile.scala    # Scala container
```

## Key Features

### Analytics Dashboard
- Productivity metrics (completion velocity, average completion time)
- Team performance tracking
- Estimation accuracy stats
- Pressure alerts and burnout detection

### Workload Management
- Visual capacity tracking per team member
- Utilization percentages (underutilized/optimal/overloaded)
- Suggested workload distribution from Scala optimizer

### Smart Scheduling
- Optimized task assignments
- Weekly timeline view
- Deadline risk assessment

### Simulation Engine
- "What-if" scenarios (add team member, drop low-priority tasks, etc.)
- Monte Carlo simulation for predictions
- Configurable parameters

### Task Estimation
- Multi-strategy estimation (historical, complexity-based, user-specific)
- Learns from completed tasks
- Tracks accuracy over time

## Development

### Running Rails Console
```bash
docker compose exec rails-app bundle exec rails console
```

### Viewing Logs
```bash
# Rails logs
docker compose logs -f rails-app

# Scala service logs
docker compose logs -f scala-task-engine
```

### Restarting Services
```bash
# Restart everything
docker compose restart

# Restart just Rails
docker compose restart rails-app
```

### Testing the Scala Service
```bash
# Health check
curl http://localhost:8080/health

# Score some tasks
curl -X POST http://localhost:8080/score-tasks \
  -H "Content-Type: application/json" \
  -d '[{"id": "123", "priority": 5, "due_date": "2024-12-05", "status": "open", "complexity": 3}]'
```

## Environment Variables

Key variables (set in `docker-compose.yml`):
- `DATABASE_HOST`, `DATABASE_USER`, `DATABASE_PASSWORD` - PostgreSQL connection
- `REDIS_URL` - Redis for Sidekiq
- `SCALA_TASK_ENGINE_URL` - Where to find the Scala service
- `SECRET_KEY_BASE` - Rails secret (use a real one in production!)

## Database Schema

Main tables:
- `organizations` - Multi-tenant orgs
- `users` - User accounts (Devise auth)
- `memberships` - User-org relationships with roles
- `projects` - Projects within orgs
- `tasks` - Tasks with status, priority, due dates, estimates
- `task_events` - Event log for task lifecycle
- `estimation_accuracy` - Tracks actual vs estimated hours
- `user_metrics` - Aggregated user performance data

## Architecture Notes

The Rails app and Scala service are completely separate. Rails makes HTTP requests to Scala when it needs:
- Task scoring/prioritization
- Workload optimization
- Capacity forecasting
- Simulations
- Estimation calculations

This makes it easy to scale them independently or even deploy them separately if needed.

## Troubleshooting

**Migrations fail with "table already exists":**
- The Scala service might have auto-created some tables. The migrations handle this, but if you see errors, check `TaskForge/db/MIGRATION_FIX.md`

**Can't connect to database:**
- Make sure PostgreSQL container is healthy: `docker compose ps`
- Check logs: `docker compose logs postgres`

**Scala service not responding:**
- Check if it's running: `docker compose ps scala-task-engine`
- Check logs: `docker compose logs scala-task-engine`
- Make sure it can reach PostgreSQL

**Port already in use:**
- Change the port mappings in `docker-compose.yml` if 3000 or 8080 are taken

## What's Next

- Add more analytics visualizations
- Implement webhooks for external integrations
- Add more simulation scenarios
- Improve the estimation learning algorithm

---

Built with Rails 8, Scala 2.13, Akka HTTP, PostgreSQL, and Docker.
