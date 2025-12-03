# Test Data Seed Files

This directory contains seed files to populate your database with realistic historical data for testing the Scala features.

## Files

1. **`seeds_test_data.rb`** - Ruby/Rails seed file (recommended)
   - Uses Rails models and Devise password hashing
   - More accurate and maintainable
   - Handles relationships properly

2. **`seeds_test_data.sql`** - Direct SQL seed file
   - Can be run directly against PostgreSQL
   - Faster for bulk data loading
   - Less accurate password hashes (use Ruby version for auth testing)

## What Gets Created

### Organization
- **Acme Software Inc.** - Main test organization

### Users (5 users)
- Alice Johnson (alice@acme.com) - Admin
- Bob Smith (bob@acme.com) - Member
- Charlie Brown (charlie@acme.com) - Member
- Diana Prince (diana@acme.com) - Member
- Eve Williams (eve@acme.com) - Member

**Password for all users:** `password123`

### Projects (5 projects)
- Website Redesign
- Mobile App
- API Development
- Data Migration
- Security Audit

### Tasks (~90 tasks total)
- **30 Completed tasks** - Historical data spanning 60 days
- **15 In-progress tasks** - Currently being worked on
- **40 Open tasks** - Mix of:
  - Overdue tasks (high priority)
  - Due soon (within 3 days)
  - Future tasks (4-30 days out)
- **5 Urgent overdue tasks** - Priority 5, overdue

### Task Events
- Created events for all tasks
- Started events for in-progress and completed tasks
- Completed events for completed tasks
- Some reassigned events (in Ruby version)

### Daily Metrics
- 60 days of historical metrics (Ruby version only)
- Includes tasks created, completed, avg lead time, open tasks count

## Usage

### Ruby Seed File (Recommended)

```bash
# Option 1: Run directly with Rails runner
cd TaskForge
rails runner db/seeds_test_data.rb

# Option 2: Use as a seed file
rails db:seed:replant SEED_FILE=db/seeds_test_data.rb
```

### SQL Seed File

```bash
# Connect to your database and run
psql -d taskforge_development -f db/seeds_test_data.sql

# Or from Rails console
rails dbconsole < db/seeds_test_data.sql
```

## Testing Scala Features

After seeding, you can test:

### 1. Schedule Optimizer
```bash
curl -X POST http://localhost:8080/optimize-schedule \
  -H "Content-Type: application/json" \
  -d '{
    "users": [
      {"id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "capacityHours": 40},
      {"id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", "capacityHours": 35}
    ],
    "tasks": [
      {"id": "<task-id>", "estimateHours": 10, "priority": 5, "dueDate": "2025-12-10", "status": "open"}
    ]
  }'
```

### 2. Streaming Analytics
The analytics service will automatically process task_events. Check metrics:
```bash
curl http://localhost:8080/analytics/user/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
curl http://localhost:8080/analytics/alerts?threshold=0.7
```

### 3. Priority Engine
```bash
curl -X POST http://localhost:8080/priority/calculate \
  -H "Content-Type: application/json" \
  -d '{
    "task": {
      "id": "test-1",
      "estimateHours": 5,
      "priority": 4,
      "dueDate": "2025-12-05",
      "status": "open",
      "complexity": 3,
      "tags": []
    }
  }'
```

### 4. Forecasting
```bash
curl -X POST http://localhost:8080/forecast \
  -H "Content-Type: application/json" \
  -d '{
    "users": [
      {"id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "capacityHours": 40}
    ],
    "tasks": [],
    "organizationId": "11111111-1111-1111-1111-111111111111"
  }'
```

### 5. Simulation
```bash
curl -X POST http://localhost:8080/simulate \
  -H "Content-Type: application/json" \
  -d '{
    "users": [
      {"id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "capacityHours": 40}
    ],
    "tasks": [],
    "config": {
      "weeks": 4,
      "newUserCapacity": 20,
      "dropLowPriority": false
    }
  }'
```

## Organization ID

Use this ID for testing:
```
11111111-1111-1111-1111-111111111111
```

## User IDs

- Alice: `aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa`
- Bob: `bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb`
- Charlie: `cccccccc-cccc-cccc-cccc-cccccccccccc`
- Diana: `dddddddd-dddd-dddd-dddd-dddddddddddd`
- Eve: `eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee`

## Notes

- The Ruby seed file creates more realistic data with proper timestamps and relationships
- Task events are properly linked to users and tasks
- Daily metrics are calculated based on actual task completion times
- All dates are relative to "now" so data stays current
- The SQL file is a simplified version - use Ruby version for best results

