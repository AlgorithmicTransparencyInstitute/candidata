class AddFieldsToPeople < ActiveRecord::Migration[7.2]
  def change
    add_column :people, :person_uuid, :string
    add_column :people, :middle_name, :string
    add_column :people, :suffix, :string
    add_column :people, :gender, :string
    add_column :people, :race, :string
    add_column :people, :photo_url, :string
    add_column :people, :website_official, :string
    add_column :people, :website_campaign, :string
    add_column :people, :website_personal, :string
    add_column :people, :airtable_id, :string

    add_index :people, :person_uuid, unique: true
    add_index :people, :airtable_id, unique: true
  end
end
