class AddFieldsToOfficeholders < ActiveRecord::Migration[7.2]
  def change
    add_column :officeholders, :elected_year, :integer
    add_column :officeholders, :appointed, :boolean, default: false
    add_column :officeholders, :airtable_id, :string

    add_index :officeholders, :elected_year
    add_index :officeholders, :airtable_id, unique: true
  end
end
