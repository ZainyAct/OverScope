-- Test Data SQL Seed File
-- This creates realistic historical data for testing Scala features
-- Run with: psql -d taskforge_development -f db/seeds_test_data.sql

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Clear existing test data (optional - comment out if you want to keep existing data)
-- DELETE FROM task_events WHERE task_id IN (SELECT id FROM tasks WHERE project_id IN (SELECT id FROM projects WHERE organization_id IN (SELECT id FROM organizations WHERE name = 'Acme Software Inc.')));
-- DELETE FROM tasks WHERE project_id IN (SELECT id FROM projects WHERE organization_id IN (SELECT id FROM organizations WHERE name = 'Acme Software Inc.'));
-- DELETE FROM task_metrics_daily WHERE organization_id IN (SELECT id FROM organizations WHERE name = 'Acme Software Inc.');
-- DELETE FROM memberships WHERE organization_id IN (SELECT id FROM organizations WHERE name = 'Acme Software Inc.');
-- DELETE FROM projects WHERE organization_id IN (SELECT id FROM organizations WHERE name = 'Acme Software Inc.');
-- DELETE FROM users WHERE email LIKE '%@acme.com';
-- DELETE FROM organizations WHERE name = 'Acme Software Inc.';

BEGIN;

-- Create organization
INSERT INTO organizations (id, name, created_at, updated_at)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'Acme Software Inc.', NOW() - INTERVAL '6 months', NOW() - INTERVAL '6 months')
ON CONFLICT (id) DO NOTHING;

-- Create users (using a simple password hash - in production use Devise)
-- Password: password123 (bcrypt hash)
INSERT INTO users (id, email, encrypted_password, full_name, created_at, updated_at)
VALUES 
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'alice@acme.com', '$2a$12$KIXx.example.hash.here', 'Alice Johnson', NOW() - INTERVAL '5 months', NOW() - INTERVAL '5 months'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'bob@acme.com', '$2a$12$KIXx.example.hash.here', 'Bob Smith', NOW() - INTERVAL '5 months', NOW() - INTERVAL '5 months'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'charlie@acme.com', '$2a$12$KIXx.example.hash.here', 'Charlie Brown', NOW() - INTERVAL '5 months', NOW() - INTERVAL '5 months'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'diana@acme.com', '$2a$12$KIXx.example.hash.here', 'Diana Prince', NOW() - INTERVAL '5 months', NOW() - INTERVAL '5 months'),
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'eve@acme.com', '$2a$12$KIXx.example.hash.here', 'Eve Williams', NOW() - INTERVAL '5 months', NOW() - INTERVAL '5 months')
ON CONFLICT (email) DO NOTHING;

-- Create memberships
INSERT INTO memberships (id, user_id, organization_id, role, created_at, updated_at)
VALUES 
  ('m1-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'admin', NOW() - INTERVAL '5 months', NOW() - INTERVAL '5 months'),
  ('m2-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'member', NOW() - INTERVAL '5 months', NOW() - INTERVAL '5 months'),
  ('m3-3333-3333-3333-333333333333', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'member', NOW() - INTERVAL '5 months', NOW() - INTERVAL '5 months'),
  ('m4-4444-4444-4444-444444444444', 'dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', 'member', NOW() - INTERVAL '5 months', NOW() - INTERVAL '5 months'),
  ('m5-5555-5555-5555-555555555555', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '11111111-1111-1111-1111-111111111111', 'member', NOW() - INTERVAL '5 months', NOW() - INTERVAL '5 months')
ON CONFLICT (user_id, organization_id) DO NOTHING;

-- Create projects
INSERT INTO projects (id, organization_id, name, description, created_at, updated_at)
VALUES 
  ('p1-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'Website Redesign', 'Complete redesign of company website', NOW() - INTERVAL '4 months', NOW() - INTERVAL '4 months'),
  ('p2-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Mobile App', 'iOS and Android mobile application', NOW() - INTERVAL '4 months', NOW() - INTERVAL '4 months'),
  ('p3-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'API Development', 'RESTful API for third-party integrations', NOW() - INTERVAL '4 months', NOW() - INTERVAL '4 months'),
  ('p4-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Data Migration', 'Migrate legacy data to new system', NOW() - INTERVAL '4 months', NOW() - INTERVAL '4 months'),
  ('p5-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'Security Audit', 'Comprehensive security review', NOW() - INTERVAL '4 months', NOW() - INTERVAL '4 months')
ON CONFLICT (id) DO NOTHING;

-- Create completed tasks with events (for historical analytics)
-- Note: This is a simplified version. For full data, use the Ruby seed file.

-- Sample completed tasks
INSERT INTO tasks (id, project_id, title, description, priority, status, due_date, created_at, updated_at)
SELECT 
  gen_random_uuid(),
  (SELECT id FROM projects WHERE organization_id = '11111111-1111-1111-1111-111111111111' ORDER BY RANDOM() LIMIT 1),
  'Completed Task ' || generate_series || ': ' || (ARRAY['Fix bug', 'Implement feature', 'Write tests', 'Code review', 'Update docs'])[floor(random() * 5 + 1)],
  'This task was completed',
  floor(random() * 5 + 1)::int,
  'completed',
  CURRENT_DATE - (random() * 60)::int,
  NOW() - INTERVAL '60 days' + (generate_series * INTERVAL '2 days'),
  NOW() - INTERVAL '60 days' + (generate_series * INTERVAL '2 days') + INTERVAL '5 days'
FROM generate_series(1, 30);

-- Create task events for completed tasks
INSERT INTO task_events (id, task_id, event_type, actor_user_id, created_at, updated_at)
SELECT 
  gen_random_uuid(),
  t.id,
  'created',
  (SELECT id FROM users WHERE email LIKE '%@acme.com' ORDER BY RANDOM() LIMIT 1),
  t.created_at,
  t.created_at
FROM tasks t
WHERE t.status = 'completed' AND t.project_id IN (SELECT id FROM projects WHERE organization_id = '11111111-1111-1111-1111-111111111111');

INSERT INTO task_events (id, task_id, event_type, actor_user_id, created_at, updated_at)
SELECT 
  gen_random_uuid(),
  t.id,
  'started',
  (SELECT id FROM users WHERE email LIKE '%@acme.com' ORDER BY RANDOM() LIMIT 1),
  t.created_at + INTERVAL '2 days',
  t.created_at + INTERVAL '2 days'
FROM tasks t
WHERE t.status = 'completed' AND t.project_id IN (SELECT id FROM projects WHERE organization_id = '11111111-1111-1111-1111-111111111111');

INSERT INTO task_events (id, task_id, event_type, actor_user_id, created_at, updated_at)
SELECT 
  gen_random_uuid(),
  t.id,
  'completed',
  (SELECT id FROM users WHERE email LIKE '%@acme.com' ORDER BY RANDOM() LIMIT 1),
  t.updated_at,
  t.updated_at
FROM tasks t
WHERE t.status = 'completed' AND t.project_id IN (SELECT id FROM projects WHERE organization_id = '11111111-1111-1111-1111-111111111111');

-- Create in-progress tasks
INSERT INTO tasks (id, project_id, title, description, priority, status, due_date, created_at, updated_at)
SELECT 
  gen_random_uuid(),
  (SELECT id FROM projects WHERE organization_id = '11111111-1111-1111-1111-111111111111' ORDER BY RANDOM() LIMIT 1),
  'In Progress Task ' || generate_series || ': ' || (ARRAY['Refactor code', 'Add tests', 'Fix issue', 'Optimize query', 'Design UI'])[floor(random() * 5 + 1)],
  'Currently being worked on',
  floor(random() * 4 + 2)::int,
  'in_progress',
  CURRENT_DATE + (random() * 14)::int,
  NOW() - (random() * 30)::int * INTERVAL '1 day',
  NOW() - (random() * 30)::int * INTERVAL '1 day' + INTERVAL '1 day'
FROM generate_series(1, 15);

-- Create task events for in-progress tasks
INSERT INTO task_events (id, task_id, event_type, actor_user_id, created_at, updated_at)
SELECT 
  gen_random_uuid(),
  t.id,
  'created',
  (SELECT id FROM users WHERE email LIKE '%@acme.com' ORDER BY RANDOM() LIMIT 1),
  t.created_at,
  t.created_at
FROM tasks t
WHERE t.status = 'in_progress' AND t.project_id IN (SELECT id FROM projects WHERE organization_id = '11111111-1111-1111-1111-111111111111');

INSERT INTO task_events (id, task_id, event_type, actor_user_id, created_at, updated_at)
SELECT 
  gen_random_uuid(),
  t.id,
  'started',
  (SELECT id FROM users WHERE email LIKE '%@acme.com' ORDER BY RANDOM() LIMIT 1),
  t.updated_at,
  t.updated_at
FROM tasks t
WHERE t.status = 'in_progress' AND t.project_id IN (SELECT id FROM projects WHERE organization_id = '11111111-1111-1111-1111-111111111111');

-- Create open tasks (mix of overdue, due soon, and future)
INSERT INTO tasks (id, project_id, title, description, priority, status, due_date, created_at, updated_at)
SELECT 
  gen_random_uuid(),
  (SELECT id FROM projects WHERE organization_id = '11111111-1111-1111-1111-111111111111' ORDER BY RANDOM() LIMIT 1),
  'Open Task ' || generate_series || ': ' || (ARRAY['New feature', 'Bug fix', 'Enhancement', 'Research', 'Documentation'])[floor(random() * 5 + 1)],
  'Task waiting to be started',
  floor(random() * 5 + 1)::int,
  'open',
  CASE 
    WHEN random() < 0.2 THEN CURRENT_DATE - (random() * 10 + 1)::int  -- Overdue
    WHEN random() < 0.5 THEN CURRENT_DATE + (random() * 3)::int         -- Due soon
    ELSE CURRENT_DATE + (random() * 26 + 4)::int                        -- Future
  END,
  NOW() - (random() * 45)::int * INTERVAL '1 day',
  NOW() - (random() * 45)::int * INTERVAL '1 day'
FROM generate_series(1, 40);

-- Create task events for open tasks
INSERT INTO task_events (id, task_id, event_type, actor_user_id, created_at, updated_at)
SELECT 
  gen_random_uuid(),
  t.id,
  'created',
  (SELECT id FROM users WHERE email LIKE '%@acme.com' ORDER BY RANDOM() LIMIT 1),
  t.created_at,
  t.created_at
FROM tasks t
WHERE t.status = 'open' AND t.project_id IN (SELECT id FROM projects WHERE organization_id = '11111111-1111-1111-1111-111111111111');

-- Create some high-priority overdue tasks
INSERT INTO tasks (id, project_id, title, description, priority, status, due_date, created_at, updated_at)
SELECT 
  gen_random_uuid(),
  (SELECT id FROM projects WHERE organization_id = '11111111-1111-1111-1111-111111111111' ORDER BY RANDOM() LIMIT 1),
  'URGENT: Critical Task ' || generate_series,
  'This is a high-priority overdue task',
  5,
  'open',
  CURRENT_DATE - (random() * 7 + 1)::int,
  NOW() - (random() * 10 + 5)::int * INTERVAL '1 day',
  NOW() - (random() * 10 + 5)::int * INTERVAL '1 day'
FROM generate_series(1, 5);

INSERT INTO task_events (id, task_id, event_type, actor_user_id, created_at, updated_at)
SELECT 
  gen_random_uuid(),
  t.id,
  'created',
  (SELECT id FROM users WHERE email LIKE '%@acme.com' ORDER BY RANDOM() LIMIT 1),
  t.created_at,
  t.created_at
FROM tasks t
WHERE t.priority = 5 AND t.status = 'open' AND t.due_date < CURRENT_DATE AND t.project_id IN (SELECT id FROM projects WHERE organization_id = '11111111-1111-1111-1111-111111111111');

COMMIT;

-- Display summary
SELECT 
  'Summary' as info,
  (SELECT COUNT(*) FROM organizations WHERE name = 'Acme Software Inc.') as organizations,
  (SELECT COUNT(*) FROM users WHERE email LIKE '%@acme.com') as users,
  (SELECT COUNT(*) FROM projects WHERE organization_id = '11111111-1111-1111-1111-111111111111') as projects,
  (SELECT COUNT(*) FROM tasks WHERE project_id IN (SELECT id FROM projects WHERE organization_id = '11111111-1111-1111-1111-111111111111')) as tasks,
  (SELECT COUNT(*) FROM task_events WHERE task_id IN (SELECT id FROM tasks WHERE project_id IN (SELECT id FROM projects WHERE organization_id = '11111111-1111-1111-1111-111111111111'))) as task_events;

SELECT 'Organization ID for testing:' as info, id::text as organization_id FROM organizations WHERE name = 'Acme Software Inc.';

