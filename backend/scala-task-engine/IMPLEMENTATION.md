# Scala Task Engine - Implementation Summary

This document summarizes the implementation of the advanced Scala features for the OverScope application.

## ✅ Completed Features

### 1. Workload & Schedule Optimizer
**Location**: `src/main/scala/com/taskforge/services/ScheduleOptimizer.scala`

- **Greedy Assignment**: Assigns tasks by priority to users with least load
- **Round-Robin Assignment**: Distributes tasks evenly across users
- **Random Variations**: Generates multiple candidate schedules for optimization
- **Scoring System**: Evaluates plans based on:
  - Lateness penalties (tasks completed after due date)
  - Overload penalties (users exceeding capacity)
  - Priority coverage (high-priority tasks assigned first)

**Endpoint**: `POST /optimize-schedule`
```json
{
  "users": [
    { "id": "u1", "capacityHours": 30, "skills": [] }
  ],
  "tasks": [
    { "id": "t1", "estimateHours": 5, "priority": 5, "dueDate": "2025-04-10", "status": "open" }
  ]
}
```

### 2. Streaming Analytics on task_events
**Location**: `src/main/scala/com/taskforge/services/StreamingAnalytics.scala`

- **Akka Streams Integration**: Continuous polling and processing of task events
- **Real-time Metrics**: Tracks user metrics (completion times, throughput, pressure scores)
- **Organization Metrics**: Aggregates daily metrics per organization
- **Pressure Score Calculation**: Detects workload pressure based on load ratio and completion rates
- **Automatic Updates**: Periodically syncs metrics to PostgreSQL

**Endpoints**:
- `GET /analytics/user/:userId` - Get user metrics
- `GET /analytics/alerts?threshold=0.7` - Get pressure alerts

### 3. Rule-based Priority Engine with DSL
**Location**: `src/main/scala/com/taskforge/services/PriorityEngine.scala`

- **Condition DSL**: 
  - `DueWithin(days)`, `Overdue()`, `MaxComplexity(n)`, `HasTag(tag)`, `HasStatus(status)`
  - Logical operators: `And(...)`, `Or(...)`, `Not(...)`
- **Effect DSL**:
  - `Boost(factor)`, `Penalty(factor)`, `SetScore(score)`, `AddScore(amount)`
- **Configurable Rules**: Rules can be loaded from JSON/YAML
- **Explainable Scoring**: Returns detailed explanations for priority calculations

**Endpoints**:
- `POST /priority/calculate` - Calculate priority score
- `POST /priority/explain` - Get detailed explanation

**Example Rule**:
```scala
Rule(
  "Overdue boost",
  Overdue(),
  Boost(0.3),
  priority = 10
)
```

### 4. Capacity Forecasting & Burnout Detector
**Location**: `src/main/scala/com/taskforge/services/CapacityForecaster.scala`

- **Load Prediction**: Calculates predicted load percentage based on upcoming tasks
- **Deadline Prediction**: Predicts which deadlines will be missed
- **Risk Assessment**: Categorizes risk as "low", "medium", or "high"
- **Burnout Detection**: Monitors pressure scores and load ratios
- **Trend Analysis**: Uses linear regression to predict future capacity

**Endpoints**:
- `POST /forecast` - Forecast capacity and deadlines
- `GET /forecast/burnout?threshold=0.8` - Detect burnout risks

**Response Example**:
```json
{
  "userId": "u1",
  "risk": "high",
  "reason": "120% of typical capacity - severe overload risk",
  "predictedLoadPercent": 120.0,
  "predictedMissedDeadlines": 3
}
```

### 5. Event Simulation Mode (What-if Engine)
**Location**: `src/main/scala/com/taskforge/services/SimulationEngine.scala`

- **Scenario Planning**: Simulates weeks of work with different configurations
- **Configuration Options**:
  - Add new users with specified capacity
  - Delay projects by weeks
  - Drop low-priority tasks
- **Outcome Metrics**: 
  - Tasks completed
  - Deadlines missed
  - User load distribution
  - Total hours worked
- **Monte Carlo Support**: Can run multiple iterations with variance for uncertainty

**Endpoint**: `POST /simulate`
```json
{
  "users": [...],
  "tasks": [...],
  "config": {
    "weeks": 4,
    "newUserCapacity": 20,
    "delayProjectWeeks": 2,
    "dropLowPriority": false
  }
}
```

## Database Integration

**Location**: `src/main/scala/com/taskforge/db/Database.scala`

- **Connection Pooling**: Uses HikariCP for efficient database connections
- **Task Events**: Fetches and processes task events from PostgreSQL
- **Metrics Storage**: Upserts user and organization metrics
- **Task Fetching**: Retrieves tasks for organizations

## Domain Models

**Location**: `src/main/scala/com/taskforge/models/DomainModels.scala`

Comprehensive domain models with JSON serialization:
- `User`, `Task`, `Assignment`, `Plan`
- `TaskEvent`, `UserMetrics`, `OrganizationMetrics`
- `ForecastResult`, `SimConfig`, `SimOutcome`

## Main Service

**Location**: `src/main/scala/com/taskforge/TaskEngine.scala`

Integrated HTTP server with all endpoints:
- Health checks
- Legacy task scoring (backward compatible)
- All new optimization and analytics endpoints
- Database initialization
- Streaming analytics startup

## Configuration

The service reads configuration from environment variables:
- `DATABASE_URL` - PostgreSQL connection URL
- `DB_USER` - Database username
- `DB_PASSWORD` - Database password

Default: `jdbc:postgresql://localhost:5432/overscope`

## Dependencies

Added to `build.sbt`:
- HikariCP for connection pooling
- Scala collection contrib for additional utilities
- Typesafe Config (already had Akka HTTP, Streams, etc.)

## Usage Examples

### Optimize Schedule
```bash
curl -X POST http://localhost:8080/optimize-schedule \
  -H "Content-Type: application/json" \
  -d '{
    "users": [{"id": "u1", "capacityHours": 40}],
    "tasks": [{"id": "t1", "estimateHours": 10, "priority": 5, "dueDate": "2025-04-15", "status": "open"}]
  }'
```

### Run Simulation
```bash
curl -X POST http://localhost:8080/simulate \
  -H "Content-Type: application/json" \
  -d '{
    "users": [{"id": "u1", "capacityHours": 40}],
    "tasks": [{"id": "t1", "estimateHours": 10, "priority": 5, "dueDate": "2025-04-15", "status": "open"}],
    "config": {"weeks": 4, "dropLowPriority": true}
  }'
```

### Get Forecast
```bash
curl -X POST http://localhost:8080/forecast \
  -H "Content-Type: application/json" \
  -d '{
    "users": [{"id": "u1", "capacityHours": 40}],
    "tasks": [{"id": "t1", "estimateHours": 10, "priority": 5, "dueDate": "2025-04-15", "status": "open"}]
  }'
```

## Next Steps (Future Enhancements)

1. **Enhanced Database Queries**: Add more sophisticated queries for historical data
2. **Machine Learning**: Integrate ML models for better predictions
3. **Caching**: Add Redis caching for frequently accessed metrics
4. **WebSocket Support**: Real-time updates for analytics dashboards
5. **Rule Configuration UI**: Allow rules to be configured via API
6. **Advanced Optimization**: Implement genetic algorithms or simulated annealing
7. **Multi-Objective Optimization**: Balance multiple goals (lateness, overload, fairness)

## Architecture Benefits

- **Type Safety**: Strong typing prevents runtime errors
- **Concurrency**: Akka Streams handles backpressure and resource management
- **Scalability**: Stateless services can be horizontally scaled
- **Maintainability**: Clear separation of concerns with service modules
- **Testability**: Pure functions and immutable data structures

