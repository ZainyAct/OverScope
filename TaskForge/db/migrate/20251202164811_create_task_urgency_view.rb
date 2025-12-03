class CreateTaskUrgencyView < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      CREATE VIEW task_urgency AS
      SELECT
        t.id,
        t.project_id,
        t.title,
        t.due_date,
        t.priority,
        RANK() OVER (
          PARTITION BY t.project_id
          ORDER BY t.priority DESC, t.due_date ASC NULLS LAST
        ) AS urgency_rank
      FROM tasks t
      WHERE t.status IN ('open', 'in_progress');
    SQL
  end

  def down
    execute "DROP VIEW IF EXISTS task_urgency;"
  end
end

