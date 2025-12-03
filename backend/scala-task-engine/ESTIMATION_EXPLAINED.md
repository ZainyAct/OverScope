# How Task Estimation Works

## Current Implementation

### 1. **Estimate Storage**
Currently, **task estimates are NOT stored in the database**. The `tasks` table in PostgreSQL doesn't have an `estimate_hours` field.

### 2. **How Estimates Are Provided**

**Option A: Client-Provided (Recommended)**
When calling the Scala API endpoints, clients must provide `estimateHours` in the request:

```json
{
  "tasks": [
    {
      "id": "t1",
      "estimateHours": 10,  // ← Client provides this
      "priority": 5,
      "dueDate": "2025-04-10",
      "status": "open"
    }
  ]
}
```

**Option B: Database Fetch (Default Fallback)**
When fetching tasks from the database (via `Database.fetchTasksForOrganization()`), the system uses a **default of 5 hours**:

```scala
// In Database.scala
val estimateHours = 5 // Default estimate
```

This is a placeholder - in production, you'd want to:
- Add an `estimate_hours` column to the `tasks` table, OR
- Calculate estimates based on historical data, OR
- Use a more sophisticated estimation algorithm

### 3. **How Estimates Are Used**

#### **Schedule Optimizer**
- Checks if user has capacity: `userLoads(u.id) + task.estimateHours <= u.capacityHours`
- Calculates completion dates: `startDate.plusDays((task.estimateHours / 8.0).ceil.toInt)`
- Tracks total load: `userLoads(user.id) += task.estimateHours`

#### **Capacity Forecasting**
- Sums up predicted hours: `predictedHours = userTasks.map(_.estimateHours).sum`
- Calculates load percentage: `loadPercent = (predictedHours / user.capacityHours) * 100.0`
- Predicts missed deadlines based on throughput vs. estimated hours

#### **Simulation Engine**
- Uses estimates to simulate task completion
- Applies variance in Monte Carlo mode: `(task.estimateHours * (1.0 + variance)).toInt`

### 4. **Current Limitations**

❌ **No Historical Learning**
- The system doesn't learn from actual vs. estimated times
- No automatic estimation improvement based on past performance

❌ **No Database Storage**
- Estimates must be provided with each API call
- Can't query historical estimates

❌ **Fixed Default**
- All database-fetched tasks get 5 hours (not realistic)

❌ **No Complexity-Based Estimation**
- The `complexity` field exists but isn't used for estimation

## Recommended Improvements

### 1. **Add Estimate Column to Database**

```sql
ALTER TABLE tasks ADD COLUMN estimate_hours INTEGER DEFAULT 5;
```

Then update `Database.fetchTasksForOrganization()`:
```scala
val estimateHours = rs.getInt("estimate_hours")
```

### 2. **Estimation Service**

Create an estimation service that learns from history:

```scala
object EstimationService {
  def estimateTask(task: Task, userId: Option[String]): Int = {
    // Option 1: Use historical average for similar tasks
    val historicalAvg = Database.getAverageCompletionTime(
      task.complexity, 
      task.priority,
      userId
    )
    
    // Option 2: Use complexity-based estimation
    val complexityBased = task.complexity match {
      case 1 => 2  // Simple
      case 2 => 4  // Easy
      case 3 => 8  // Medium
      case 4 => 16 // Hard
      case 5 => 32 // Very Hard
      case _ => 8
    }
    
    // Option 3: User-specific adjustment
    userId.flatMap(Database.fetchUserMetrics).map { metrics =>
      val userMultiplier = metrics.avgCompletionHours / 8.0 // Normalize to 8h baseline
      (complexityBased * userMultiplier).toInt
    }.getOrElse(complexityBased)
  }
}
```

### 3. **Estimate vs. Actual Tracking**

Track estimation accuracy:

```scala
case class EstimationAccuracy(
  taskId: String,
  estimatedHours: Int,
  actualHours: Double,
  accuracy: Double // actual / estimated
)

def trackEstimationAccuracy(task: Task, actualHours: Double): Unit = {
  val accuracy = actualHours / task.estimateHours
  Database.saveEstimationAccuracy(EstimationAccuracy(
    task.id,
    task.estimateHours,
    actualHours,
    accuracy
  ))
}
```

### 4. **Auto-Estimation Endpoint**

Add an endpoint that suggests estimates:

```scala
path("estimate") {
  post {
    entity(as[Task]) { task =>
      val estimate = EstimationService.estimateTask(task, None)
      complete(Map("estimateHours" -> estimate, "method" -> "complexity-based"))
    }
  }
}
```

## Current Workflow

```
┌─────────────┐
│   Rails     │
│  (Client)   │
└──────┬──────┘
       │ Provides estimateHours in API request
       ▼
┌─────────────────────┐
│  Scala Task Engine  │
│                     │
│  - Schedule         │
│    Optimizer        │ ← Uses estimateHours
│                     │
│  - Capacity         │
│    Forecaster       │ ← Uses estimateHours
│                     │
│  - Simulation       │
│    Engine           │ ← Uses estimateHours
└─────────────────────┘
```

## Summary

**Current State:**
- ✅ Estimates are used throughout the system
- ✅ Client can provide estimates via API
- ⚠️ Database defaults to 5 hours (not ideal)
- ❌ No learning from historical data
- ❌ No automatic estimation

**Best Practice:**
Always provide `estimateHours` when calling the Scala API. If you're fetching tasks from the database, consider adding an `estimate_hours` column or implementing an estimation service.

