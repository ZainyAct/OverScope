# Migration Instructions

## Issue: Table Already Exists

If you get an error that `estimation_accuracy` or `user_metrics` table already exists, it's because the Scala service created them automatically. Here's how to fix it:

### Option 1: Mark Migration as Run (Recommended)

If the tables already exist and have the correct structure:

```bash
# Mark the migrations as run without executing them
rails db:migrate:status  # Check status
rails db:schema:dump     # Update schema.rb to match current DB state
```

### Option 2: Drop and Recreate (If you want clean migrations)

```bash
# Drop the tables created by Scala service
rails dbconsole
# Then in psql:
DROP TABLE IF EXISTS estimation_accuracy CASCADE;
DROP TABLE IF EXISTS user_metrics CASCADE;
\q

# Now run migrations
rails db:migrate
```

### Option 3: Use the Fixed Migrations

The migrations have been updated to handle existing tables gracefully. They will:
- Check if table exists before creating
- Add missing columns if table exists
- Add missing indexes
- Handle foreign keys

Just run:
```bash
rails db:migrate
```

The migrations will now skip creating tables that already exist and just ensure all columns/indexes are present.

## Migration Order

1. `20251203000001_add_estimate_hours_to_tasks.rb` - Adds estimate_hours and complexity to tasks
2. `20251203000002_create_estimation_accuracy.rb` - Creates estimation_accuracy table (or updates if exists)
3. `20251203000003_fix_estimation_accuracy_if_exists.rb` - Ensures all columns exist
4. `20251203000004_create_user_metrics.rb` - Creates user_metrics table (or updates if exists)

## After Migration

Verify the schema:
```bash
rails db:schema:dump
rails db:schema:load  # If needed to reset
```

