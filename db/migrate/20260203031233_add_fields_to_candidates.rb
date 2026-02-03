class AddFieldsToCandidates < ActiveRecord::Migration[7.2]
  def change
    add_column :candidates, :party_at_time, :string
    add_column :candidates, :incumbent, :boolean, default: false
    add_column :candidates, :airtable_id, :string

    add_index :candidates, :incumbent
    add_index :candidates, :airtable_id, unique: true
  end
end
