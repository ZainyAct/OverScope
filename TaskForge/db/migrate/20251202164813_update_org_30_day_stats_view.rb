class UpdateOrg30DayStatsView < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      DROP VIEW IF EXISTS org_30_day_stats;
      
      CREATE VIEW org_30_day_stats AS
      WITH date_range AS (
        SELECT generate_series(
          CURRENT_DATE - INTERVAL '30 days',
          CURRENT_DATE,
          '1 day'::interval
        )::date AS date
      ),
      task_stats AS (
        SELECT
          p.organization_id,
          COUNT(*) FILTER (WHERE t.created_at >= CURRENT_DATE - INTERVAL '30 days') AS total_tasks,
          COUNT(*) FILTER (
            WHERE t.status = 'completed'
            AND t.created_at >= CURRENT_DATE - INTERVAL '30 days'
          ) AS completed_tasks,
          AVG(
            EXTRACT(EPOCH FROM (
              SELECT MIN(te.created_at)
              FROM task_events te
              WHERE te.task_id = t.id AND te.event_type = 'completed'
            ) - t.created_at) / 3600.0
          ) FILTER (
            WHERE t.status = 'completed'
            AND EXISTS (
              SELECT 1 FROM task_events te
              WHERE te.task_id = t.id AND te.event_type = 'completed'
            )
          ) AS avg_completion_hours
        FROM tasks t
        INNER JOIN projects p ON p.id = t.project_id
        WHERE t.created_at >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY p.organization_id
      )
      SELECT
        o.id AS organization_id,
        o.name AS organization_name,
        COALESCE(ts.total_tasks, 0) AS tasks_created_30d,
        COALESCE(ts.completed_tasks, 0) AS tasks_completed_30d,
        COALESCE(ts.avg_completion_hours, 0) AS avg_lead_time_hours,
        CASE
          WHEN COALESCE(ts.total_tasks, 0) > 0
          THEN ROUND((COALESCE(ts.completed_tasks, 0)::numeric / ts.total_tasks::numeric) * 100, 2)
          ELSE 0
        END AS completion_ratio,
        (SELECT COUNT(*) 
         FROM tasks t2
         INNER JOIN projects p2 ON p2.id = t2.project_id
         WHERE p2.organization_id = o.id
         AND t2.status IN ('open', 'in_progress')) AS open_tasks_now
      FROM organizations o
      LEFT JOIN task_stats ts ON ts.organization_id = o.id;
    SQL
  end

  def down
    execute <<-SQL
      DROP VIEW IF EXISTS org_30_day_stats;
      
      CREATE VIEW org_30_day_stats AS
      WITH date_range AS (
        SELECT generate_series(
          CURRENT_DATE - INTERVAL '30 days',
          CURRENT_DATE,
          '1 day'::interval
        )::date AS date
      ),
      task_stats AS (
        SELECT
          p.organization_id,
          COUNT(*) FILTER (WHERE t.created_at >= CURRENT_DATE - INTERVAL '30 days') AS total_tasks,
          COUNT(*) FILTER (
            WHERE t.status = 'completed'
            AND t.created_at >= CURRENT_DATE - INTERVAL '30 days'
          ) AS completed_tasks,
          AVG(
            EXTRACT(EPOCH FROM (
              SELECT MIN(te.created_at)
              FROM task_events te
              WHERE te.task_id = t.id AND te.event_type = 'completed'
            ) - t.created_at) / 3600.0
          ) FILTER (
            WHERE t.status = 'completed'
            AND EXISTS (
              SELECT 1 FROM task_events te
              WHERE te.task_id = t.id AND te.event_type = 'completed'
            )
          ) AS avg_completion_hours
        FROM tasks t
        INNER JOIN projects p ON p.id = t.project_id
        WHERE t.created_at >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY p.organization_id
      )
      SELECT
        o.id AS organization_id,
        o.name AS organization_name,
        COALESCE(ts.total_tasks, 0) AS total_tasks,
        COALESCE(ts.completed_tasks, 0) AS completed_tasks,
        COALESCE(ts.avg_completion_hours, 0) AS avg_completion_hours,
        CASE
          WHEN COALESCE(ts.total_tasks, 0) > 0
          THEN ROUND((COALESCE(ts.completed_tasks, 0)::numeric / ts.total_tasks::numeric) * 100, 2)
          ELSE 0
        END AS completion_ratio
      FROM organizations o
      LEFT JOIN task_stats ts ON ts.organization_id = o.id;
    SQL
  end
end

