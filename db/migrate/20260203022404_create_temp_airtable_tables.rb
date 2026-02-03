class CreateTempAirtableTables < ActiveRecord::Migration[7.2]
  def change
    # Temp table for People records (both federal and state)
    create_table :temp_people do |t|
      t.string :source_type # 'federal' or 'state'
      t.string :official_name
      t.string :state
      t.string :level
      t.string :role
      t.string :jurisdiction
      t.string :jurisdiction_ocdid
      t.string :electoral_district
      t.string :electoral_district_ocdid
      t.string :office_uuid
      t.string :office_name
      t.string :seat
      t.string :office_category
      t.string :body_name
      t.string :person_uuid
      t.string :registered_political_party
      t.string :race
      t.string :gender
      t.string :photo_url
      t.string :website_official
      t.string :website_campaign
      t.string :website_personal
      t.string :candidate_uuid
      t.boolean :incumbent
      t.boolean :is_2024_candidate
      t.boolean :is_2024_office_holder
      t.string :general_election_winner
      t.string :party_roll_up
      t.text :raw_data
      t.timestamps
    end

    # Temp table for Accounts records (both federal and state)
    create_table :temp_accounts do |t|
      t.string :source_type # 'federal' or 'state'
      t.string :url
      t.string :platform
      t.string :channel_type
      t.string :status
      t.string :state
      t.string :office_name
      t.string :level
      t.string :office_category
      t.string :people_name
      t.string :party_roll_up
      t.boolean :account_inactive
      t.boolean :verified
      t.text :raw_data
      t.timestamps
    end

    add_index :temp_people, :source_type
    add_index :temp_people, :state
    add_index :temp_people, :level
    add_index :temp_people, :office_category
    add_index :temp_people, :registered_political_party
    add_index :temp_people, :person_uuid

    add_index :temp_accounts, :source_type
    add_index :temp_accounts, :platform
    add_index :temp_accounts, :channel_type
    add_index :temp_accounts, :state
  end
end
