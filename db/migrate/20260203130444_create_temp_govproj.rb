class CreateTempGovproj < ActiveRecord::Migration[7.2]
  def change
    create_table :temp_govproj do |t|
      # Location/Jurisdiction
      t.string :state
      t.string :level
      t.string :jurisdiction
      t.string :jurisdiction_ocdid
      t.string :electoral_district
      t.string :electoral_district_ocdid
      t.string :county
      
      # Office
      t.string :office_uuid
      t.string :seat
      t.string :office_name
      t.string :office_category
      t.string :body_name
      t.string :role
      
      # Term/Election dates
      t.string :term_end
      t.string :expires
      t.string :officeholder_start
      t.string :next_election_date
      t.string :regular_election_date
      
      # Person
      t.string :person_uuid
      t.string :official_name
      t.string :dob
      t.string :wiki_word
      t.string :photo_url
      
      # Party
      t.string :registered_political_party
      t.string :party_roll_up
      
      # Contact info
      t.string :gov_email
      t.string :gov_email_form
      t.string :gov_phone
      t.text :gov_mailing_address
      t.string :website_official
      
      # Social media
      t.string :youtube_gov
      t.string :instagram_url_gov
      t.string :twitter_name_gov
      t.string :facebook_url_gov
      t.string :tiktok_gov
      t.string :threads_gov
      
      t.timestamps
    end
    
    add_index :temp_govproj, :state
    add_index :temp_govproj, :level
    add_index :temp_govproj, :office_uuid
    add_index :temp_govproj, :person_uuid
    add_index :temp_govproj, :party_roll_up
  end
end
