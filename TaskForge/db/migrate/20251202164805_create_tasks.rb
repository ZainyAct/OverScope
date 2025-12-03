class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks, id: :uuid do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.text :description
      t.string :status, default: 'open'
      t.integer :priority, default: 3
      t.date :due_date

      t.timestamps
    end

    add_index :tasks, [:project_id, :status, :due_date]
    add_check_constraint :tasks, "priority >= 1 AND priority <= 5", name: "tasks_priority_check"
  end
end

