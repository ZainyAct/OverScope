# Migration Fix Instructions

## Problem
1. `schema.rb` is owned by root (permission denied)
2. Tables might already exist from Scala service
3. Migrations need to handle existing tables gracefully

## Solution

### Step 1: Fix schema.rb permissions
```bash
sudo chown $USER:$USER db/schema.rb
```

### Step 2: Run migrations
The migrations are now simplified to:
- Skip table creation if table already exists
- A separate migration (`20251203000006_ensure_estimation_tables_structure.rb`) will add any missing columns to existing tables

```bash
cd TaskForge
rails db:migrate
```

### Step 3: If migrations still fail

If tables exist but have wrong structure, the migration `20251203000006` will fix them automatically using SQL.

## What Changed

1. **Simplified migrations**: `20251203000002` and `20251203000004` now just return early if tables exist
2. **New migration**: `20251203000006` ensures all required columns exist on existing tables
3. **No more complex conditionals**: Cleaner, more maintainable code

## Alternative: Use Docker's postgres client

If you prefer to use SQL directly:

```bash
# Connect via Docker
docker compose -f docker/docker-compose.yml exec postgres psql -U taskforge -d taskforge_development

# Then run the SQL from db/fix_estimation_tables.sql
```

