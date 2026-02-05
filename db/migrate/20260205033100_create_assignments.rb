class CreateAssignments < ActiveRecord::Migration[7.2]
  def change
    create_table :assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :assigned_by, null: false, foreign_key: { to_table: :users }
      t.references :person, null: false, foreign_key: true
      t.string :task_type, null: false
      t.string :status, null: false, default: 'pending'
      t.datetime :completed_at
      t.text :notes

      t.timestamps
    end

    add_index :assignments, [:user_id, :person_id, :task_type], unique: true
    add_index :assignments, [:status]
    add_index :assignments, [:task_type]
  end
end
