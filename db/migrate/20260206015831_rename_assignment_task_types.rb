class RenameAssignmentTaskTypes < ActiveRecord::Migration[7.2]
  def up
    execute "UPDATE assignments SET task_type = 'data_collection' WHERE task_type = 'research'"
    execute "UPDATE assignments SET task_type = 'data_validation' WHERE task_type = 'verification'"
  end

  def down
    execute "UPDATE assignments SET task_type = 'research' WHERE task_type = 'data_collection'"
    execute "UPDATE assignments SET task_type = 'verification' WHERE task_type = 'data_validation'"
  end
end
