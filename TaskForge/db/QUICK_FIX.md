# Quick Fix for Migration Error

## Problem
The `estimation_accuracy` table already exists (created by Scala service), causing migration to fail.

## Solution

### Option 1: Run SQL Fix Script (Fastest)

```bash
# Connect to your database
rails dbconsole

# Or directly:
psql -d taskforge_development -f db/fix_estimation_tables.sql
```

This will ensure all columns and indexes exist without errors.

### Option 2: Mark Migration as Run

If the table structure is already correct:

```bash
# In Rails console or psql, mark the migration as run
rails dbconsole

# Then:
INSERT INTO schema_migrations (version) VALUES ('20251203000002') ON CONFLICT DO NOTHING;
INSERT INTO schema_migrations (version) VALUES ('20251203000004') ON CONFLICT DO NOTHING;
```

Then continue with other migrations:
```bash
rails db:migrate
```

### Option 3: Drop and Recreate (Clean Slate)

```bash
rails dbconsole

# Drop tables
DROP TABLE IF EXISTS estimation_accuracy CASCADE;
DROP TABLE IF EXISTS user_metrics CASCADE;
\q

# Run migrations
rails db:migrate
```

## Recommended: Use Option 1

The SQL fix script (`db/fix_estimation_tables.sql`) will:
- Add any missing columns
- Add missing indexes
- Add foreign keys
- Work whether tables exist or not

Then run:
```bash
rails db:migrate
```

The migrations are now idempotent and will handle existing tables gracefully.

