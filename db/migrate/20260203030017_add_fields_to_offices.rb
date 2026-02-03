class AddFieldsToOffices < ActiveRecord::Migration[7.2]
  def change
    add_column :offices, :office_category, :string
    add_column :offices, :body_name, :string
    add_column :offices, :seat, :string
    add_column :offices, :role, :string
    add_column :offices, :jurisdiction, :string
    add_column :offices, :jurisdiction_ocdid, :string
    add_column :offices, :ocdid, :string
    add_column :offices, :airtable_id, :string

    add_index :offices, :office_category
    add_index :offices, :body_name
    add_index :offices, :role
    add_index :offices, :ocdid
    add_index :offices, :airtable_id, unique: true
  end
end
