class AddGovprojFieldsToPeople < ActiveRecord::Migration[7.2]
  def change
    add_column :people, :wikipedia_id, :string
  end
end
