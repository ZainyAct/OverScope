# Task Estimation System

## Overview

The estimation system provides intelligent task hour estimation using multiple strategies, learns from historical data, and tracks accuracy over time.

## Features

### 1. **Database Schema**

**Tasks Table:**
- `estimate_hours` (integer, default: 5) - Estimated hours to complete
- `complexity` (integer, default: 3) - Task complexity (1-5)

**Estimation Accuracy Table:**
- Tracks actual vs. estimated hours for completed tasks
- Stores accuracy ratios for analysis
- Links to users for user-specific learning

### 2. **Estimation Strategies**

The `EstimationService` uses 4 strategies with weighted averaging:

1. **Historical Average (40% weight)**
   - Looks at similar tasks (same complexity + priority) completed in last 90 days
   - User-specific if userId provided

2. **Complexity-Based (30% weight)**
   - Base estimates: 1→2h, 2→4h, 3→8h, 4→16h, 5→32h

3. **Priority-Adjusted (20% weight)**
   - Adjusts complexity estimate based on priority
   - Higher priority = slightly more time (1.2x for priority 5)

4. **User-Specific (10% weight)**
   - Adjusts based on user's historical completion times
   - Normalizes to 8-hour baseline

### 3. **Automatic Tracking**

- **On Task Creation**: Auto-estimates if `estimate_hours` is blank
- **On Task Completion**: Automatically tracks accuracy (estimated vs. actual)
- **Streaming Analytics**: Integrates with event processing

## Usage

### From Rails

#### Auto-estimation on Create
```ruby
task = project.tasks.build(title: "New Task", complexity: 4)
task.save  # Automatically estimates if estimate_hours is nil
```

#### Manual Estimation
```ruby
client = ScalaTaskEngineClient.new
result = client.estimate_task(task, user_id: current_user.id)
# => { "estimateHours" => 16, "method" => "weighted_average", "breakdown" => {...} }
```

#### Track Accuracy (automatic on completion)
```ruby
# Automatically called when task status changes to 'completed'
# Or manually:
client.track_estimation_accuracy(task.id, task.estimate_hours, task.lead_time_hours, user_id: user.id)
```

#### Get Statistics
```ruby
stats = client.get_estimation_stats(user_id: user.id, organization_id: org.id)
# => { "totalTasks" => 50, "avgAccuracy" => 0.95, "avgOverestimate" => 5.2, "avgUnderestimate" => 3.1 }
```

### From Scala API

#### Estimate Task
```bash
POST /estimate
{
  "task": {
    "id": "t1",
    "estimateHours": 5,
    "priority": 4,
    "dueDate": "2025-12-10",
    "status": "open",
    "complexity": 3,
    "tags": []
  },
  "userId": "user-id-optional"
}

Response:
{
  "estimateHours": 12,
  "method": "weighted_average",
  "breakdown": {
    "complexity_based": 8.0,
    "historical": 15.0,
    "final_estimate": 12.0
  }
}
```

#### Track Accuracy
```bash
POST /estimate/track-accuracy
{
  "taskId": "t1",
  "estimatedHours": 10,
  "actualHours": 12.5,
  "userId": "user-id-optional"
}
```

#### Get Statistics
```bash
GET /estimate/stats?userId=<id>&organizationId=<id>
{
  "totalTasks": 50,
  "avgAccuracy": 0.95,
  "avgOverestimate": 5.2,
  "avgUnderestimate": 3.1
}
```

## UI Integration

### Task Form
- **Complexity dropdown**: 1-5 (Very Simple to Very Complex)
- **Estimate Hours field**: Auto-populated, editable
- **Auto-estimate button**: Recalculates based on current form values
- **Auto-estimates on complexity change**: Via Stimulus controller

### JavaScript Controller
`task_estimate_controller.js`:
- Listens to complexity changes
- Calls `/api/tasks/estimate` endpoint
- Updates estimate field with visual feedback

## Rails API Endpoints

- `GET /api/tasks/estimate?task_id=<id>&priority=4&complexity=3&due_date=2025-12-10`
- `GET /api/tasks/estimation_stats?user_id=<id>&organization_id=<id>`

## How It Works

### Estimation Flow
```
1. User creates/edits task
2. If estimate_hours is blank → auto-estimate
3. EstimationService.estimateTask() called
4. Combines 4 strategies with weights
5. Returns best estimate
6. Saved to database
```

### Accuracy Tracking Flow
```
1. Task marked as completed
2. Task model callback triggers
3. Calculates actual hours (lead_time_hours)
4. Calls EstimationService.trackAccuracy()
5. Saves to estimation_accuracy table
6. Future estimations improve using this data
```

### Learning Over Time
- Historical data accumulates in `estimation_accuracy` table
- `getAverageCompletionTime()` queries this data
- Estimates improve as more tasks are completed
- User-specific adjustments based on individual performance

## Complexity Mapping

| Complexity | Base Hours | Description |
|------------|------------|-------------|
| 1 | 2 hours | Very Simple - Quick fixes, simple updates |
| 2 | 4 hours | Simple - Standard features, routine work |
| 3 | 8 hours | Medium - Typical development tasks |
| 4 | 16 hours | Complex - Multi-day features, integrations |
| 5 | 32 hours | Very Complex - Major refactors, architecture |

## Accuracy Metrics

- **avgAccuracy**: Average of (actual / estimated) ratios
  - 1.0 = perfect estimation
  - < 1.0 = overestimated (took less time)
  - > 1.0 = underestimated (took more time)

- **avgOverestimate**: Average % we overestimated
- **avgUnderestimate**: Average % we underestimated

## Migration

Run migrations to add columns and table:

```bash
rails db:migrate
```

This will:
1. Add `estimate_hours` and `complexity` to `tasks` table
2. Create `estimation_accuracy` table

## Future Enhancements

- Machine learning model for more accurate predictions
- Team-level estimation patterns
- Project-type specific adjustments
- Confidence intervals for estimates
- Estimation history/versioning

